/**
 * Orphan webhook replay (purchase-flow.md §6.4 / §7 #6).
 *
 * Bypasses withTestTransaction because replayOrphanedEvents opens its own
 * pool-backed transaction (production behavior — auth.middleware fires it
 * fire-and-forget on first sign-in). Tests truncate before each case to
 * keep isolation.
 */
import { describe, it, expect, beforeEach } from "vitest";
import { pool } from "../../src/infrastructure/db/postgres";
import { replayOrphanedEvents } from "../../src/application/rc-webhook/apply-event";
import { PgUserRepository } from "../../src/infrastructure/db/repositories/pg-user.repository";
import { truncateTestData } from "../helpers/db";

const MONTHLY = "GFM_Monthly_4.99";

beforeEach(async () => {
  await truncateTestData();
});

async function insertOrphanEvent(args: {
  eventId: string;
  type: string;
  appUserId: string;
  productId?: string;
  ts?: number;
}): Promise<void> {
  const payload = {
    event: {
      id:                 args.eventId,
      type:               args.type,
      app_user_id:        args.appUserId,
      environment:        "PRODUCTION",
      product_id:         args.productId,
      event_timestamp_ms: args.ts ?? Date.now(),
    },
  };
  await pool.query(
    `INSERT INTO webhook_events (event_id, event_type, user_id, raw_payload)
     VALUES ($1, $2, NULL, $3::jsonb)`,
    [args.eventId, args.type, JSON.stringify(payload)],
  );
}

describe("replayOrphanedEvents", () => {
  it("applies stored INITIAL_PURCHASE and claims the orphan row for the new user", async () => {
    const sub = "orphan-sub-1";
    await insertOrphanEvent({
      eventId:   "orphan-evt-1",
      type:      "INITIAL_PURCHASE",
      appUserId: sub,
      productId: MONTHLY,
    });

    // User signs in for the first time — auth.middleware would do this.
    const userRepo = new PgUserRepository(pool);
    const { user } = await userRepo.upsert(sub, "orphan@test.example");

    await replayOrphanedEvents(sub, user.id);

    // User now credited + premium.
    const after = await userRepo.findById(user.id);
    expect(after?.isPremium).toBe(true);
    expect(after?.subscriptionProductId).toBe(MONTHLY);
    expect(after?.quotaBalance).toBe(50);

    // webhook_events row claimed (user_id no longer NULL).
    const { rows } = await pool.query(
      "SELECT user_id FROM webhook_events WHERE event_id = $1",
      ["orphan-evt-1"],
    );
    expect(rows[0]["user_id"]).toBe(user.id);
  });

  it("is a no-op for users with no orphan events", async () => {
    const userRepo = new PgUserRepository(pool);
    const { user } = await userRepo.upsert("no-orphan-sub", "no@test.example");

    await replayOrphanedEvents("no-orphan-sub", user.id);

    const after = await userRepo.findById(user.id);
    expect(after?.isPremium).toBe(false);
    expect(after?.quotaBalance).toBe(0);
  });

  it("applies multiple orphan events in arrival order", async () => {
    const sub = "orphan-multi-sub";
    await insertOrphanEvent({
      eventId:   "orphan-init",
      type:      "INITIAL_PURCHASE",
      appUserId: sub,
      productId: MONTHLY,
      ts:        Date.now() - 5_000,
    });
    await insertOrphanEvent({
      eventId:   "orphan-renew",
      type:      "RENEWAL",
      appUserId: sub,
      productId: MONTHLY,
      ts:        Date.now(),
    });

    const userRepo = new PgUserRepository(pool);
    const { user } = await userRepo.upsert(sub, "multi@test.example");

    await replayOrphanedEvents(sub, user.id);

    const after = await userRepo.findById(user.id);
    expect(after?.isPremium).toBe(true);
    // INITIAL (50) + RENEWAL (50) = 100.
    expect(after?.quotaBalance).toBe(100);
  });
});
