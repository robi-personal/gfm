/**
 * Webhook route end-to-end (supertest). Drives the real express app and
 * inspects DB state after each request. Uses truncateTestData (not a
 * test transaction) because the route opens its own pool connections.
 */
import { describe, it, expect, beforeEach, beforeAll } from "vitest";
import request from "supertest";
import type { Application } from "express";
import { pool } from "../../src/infrastructure/db/postgres";
import { truncateTestData } from "../helpers/db";

const MONTHLY = "GFM_Monthly_4.99";
const SECRET  = "test-rc-webhook-secret"; // matches vitest.config.ts env

let app: Application;

beforeAll(async () => {
  // Lazy import so vitest.config.ts env vars (RC_WEBHOOK_SECRET etc.)
  // are loaded before the module reads them at construction time.
  const { createApp } = await import("../../src/app");
  app = createApp();
});

beforeEach(async () => {
  await truncateTestData();
});

function rcEnvelope(args: {
  id: string;
  type: string;
  appUserId: string;
  productId?: string;
  ts?: number;
}): unknown {
  return {
    event: {
      id:                 args.id,
      type:               args.type,
      app_user_id:        args.appUserId,
      environment:        "PRODUCTION",
      product_id:         args.productId,
      event_timestamp_ms: args.ts ?? Date.now(),
    },
  };
}

async function seedUser(googleSub: string): Promise<number> {
  const { rows } = await pool.query(
    `INSERT INTO users (google_sub, email) VALUES ($1, $2) RETURNING id`,
    [googleSub, `${googleSub}@test.example`],
  );
  return rows[0]["id"];
}

describe("POST /webhooks/revenuecat", () => {
  it("returns 401 on bearer mismatch (auth runs before rate limit)", async () => {
    const res = await request(app)
      .post("/webhooks/revenuecat")
      .set("Authorization", "wrong-secret")
      .send(rcEnvelope({ id: "evt-bad-auth", type: "INITIAL_PURCHASE", appUserId: "anyone", productId: MONTHLY }));

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("invalid_signature");

    // No DB write whatsoever.
    const { rows } = await pool.query("SELECT count(*) FROM webhook_events");
    expect(Number(rows[0]["count"])).toBe(0);
  });

  it("processes INITIAL_PURCHASE end-to-end for a known user", async () => {
    const sub    = "http-known-user";
    const userId = await seedUser(sub);

    const res = await request(app)
      .post("/webhooks/revenuecat")
      .set("Authorization", SECRET)
      .send(rcEnvelope({ id: "evt-http-1", type: "INITIAL_PURCHASE", appUserId: sub, productId: MONTHLY }));

    expect(res.status).toBe(200);
    expect(res.body.received).toBe(true);

    const { rows: userRows } = await pool.query(
      "SELECT is_premium, quota_balance, subscription_product_id FROM users WHERE id = $1",
      [userId],
    );
    expect(userRows[0]["is_premium"]).toBe(true);
    expect(userRows[0]["quota_balance"]).toBe(50);
    expect(userRows[0]["subscription_product_id"]).toBe(MONTHLY);

    const { rows: txRows } = await pool.query(
      "SELECT source, ref_id FROM quota_transactions WHERE user_id = $1",
      [userId],
    );
    expect(txRows).toHaveLength(1);
    expect(txRows[0]["source"]).toBe("subscription");
    expect(txRows[0]["ref_id"]).toBe("evt-http-1");

    const { rows: whRows } = await pool.query(
      "SELECT user_id FROM webhook_events WHERE event_id = $1",
      ["evt-http-1"],
    );
    expect(whRows[0]["user_id"]).toBe(userId);
  });

  it("stores unknown-user event with user_id=NULL (orphan path)", async () => {
    const res = await request(app)
      .post("/webhooks/revenuecat")
      .set("Authorization", SECRET)
      .send(rcEnvelope({ id: "evt-orphan-http", type: "INITIAL_PURCHASE", appUserId: "ghost-sub", productId: MONTHLY }));

    expect(res.status).toBe(200);

    const { rows } = await pool.query(
      "SELECT user_id, raw_payload->'event'->>'app_user_id' AS app_user_id FROM webhook_events WHERE event_id = $1",
      ["evt-orphan-http"],
    );
    expect(rows[0]["user_id"]).toBeNull();
    expect(rows[0]["app_user_id"]).toBe("ghost-sub");
  });

  it("dedups a duplicate event_id (second POST is a silent no-op)", async () => {
    const sub    = "http-dup-user";
    const userId = await seedUser(sub);

    const envelope = rcEnvelope({ id: "evt-dup", type: "INITIAL_PURCHASE", appUserId: sub, productId: MONTHLY });

    const first = await request(app)
      .post("/webhooks/revenuecat")
      .set("Authorization", SECRET)
      .send(envelope);
    expect(first.status).toBe(200);

    const second = await request(app)
      .post("/webhooks/revenuecat")
      .set("Authorization", SECRET)
      .send(envelope);
    expect(second.status).toBe(200);

    // Single credit despite two POSTs.
    const { rows: userRows } = await pool.query(
      "SELECT quota_balance FROM users WHERE id = $1",
      [userId],
    );
    expect(userRows[0]["quota_balance"]).toBe(50);

    const { rows: txRows } = await pool.query(
      "SELECT count(*) FROM quota_transactions WHERE user_id = $1",
      [userId],
    );
    expect(Number(txRows[0]["count"])).toBe(1);
  });

  it("returns 400 on malformed body (missing event.id)", async () => {
    const res = await request(app)
      .post("/webhooks/revenuecat")
      .set("Authorization", SECRET)
      .send({ event: { type: "INITIAL_PURCHASE", app_user_id: "x", environment: "PRODUCTION" } });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("invalid_input");
  });
});
