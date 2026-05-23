/**
 * Direct repository tests — exercise the SQL semantics each method depends on.
 * The bugs purchase-flow.md §6.1, §6.3 and §7 (orphan replay, TRANSFER,
 * idempotency) all live in these statements; cover them here so a regression
 * to the SQL surfaces immediately.
 */
import { describe, it, expect } from "vitest";
import { PgUserRepository } from "../../src/infrastructure/db/repositories/pg-user.repository";
import {
  withTestTransaction,
  createTestUser,
  fetchUser,
  fetchTransactions,
} from "../helpers/db";

const MONTHLY = "GFM_Monthly_4.99";
const WEEKLY  = "GFM_Weekly_3.99";

describe("PgUserRepository.claimPremiumAndCredit", () => {
  it("blocks the duplicate when sync flipped is_premium first (heal-only race)", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      // Sync path: sets premium = true via setSubscriptionProduct, then credits
      // under sync-heal ref. Simulates "sync ran first".
      await repo.setSubscriptionProduct(user.id, MONTHLY, null);
      await repo.creditQuota(user.id, 50, "subscription", MONTHLY, "sync-heal:sub:monthly");

      // Webhook path arrives second. claimPremiumAndCredit must observe
      // is_premium=TRUE and short-circuit (returns false, no extra credit).
      const claimed = await repo.claimPremiumAndCredit(
        user.id, 50, MONTHLY, "subscription", "evt-webhook-late", Date.now(),
      );

      expect(claimed).toBe(false);
      const after = await fetchUser(client, user.id);
      expect(after.quotaBalance).toBe(50); // not 100
      const txs = await fetchTransactions(client, user.id);
      expect(txs).toHaveLength(1);
      expect(txs[0].refId).toBe("sync-heal:sub:monthly");
    });
  });

  it("rejects a stale event whose timestamp is older than last_event_at", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      // Recent EXPIRATION advanced last_event_at and cleared premium.
      // claimPremiumAndCredit would otherwise reactivate because is_premium=false,
      // but the watermark blocks the late INITIAL_PURCHASE.
      const recentTs = Date.now();
      const staleTs  = recentTs - 60_000; // 1 minute earlier

      await repo.setSubscriptionProduct(user.id, null, recentTs);

      const claimed = await repo.claimPremiumAndCredit(
        user.id, 50, MONTHLY, "subscription", "evt-stale", staleTs,
      );

      expect(claimed).toBe(false);
      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(false);
      expect(after.quotaBalance).toBe(0);
      expect(after.subscriptionProductId).toBeNull();
    });
  });
});

describe("PgUserRepository.creditQuota", () => {
  it("is idempotent on (user_id, source, product_id, ref_id)", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      await repo.creditQuota(user.id, 50, "subscription", MONTHLY, "evt-1");
      // Second call with identical tuple — UNIQUE partial index swallows it.
      await repo.creditQuota(user.id, 50, "subscription", MONTHLY, "evt-1");

      const after = await fetchUser(client, user.id);
      expect(after.quotaBalance).toBe(50); // single credit, not 100
      const txs = await fetchTransactions(client, user.id);
      expect(txs).toHaveLength(1);
    });
  });

  it("credits independently when ref_id differs (e.g. RENEWAL after INITIAL)", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      await repo.creditQuota(user.id, 50, "subscription", MONTHLY, "evt-initial");
      await repo.creditQuota(user.id, 50, "subscription", MONTHLY, "evt-renewal");

      const after = await fetchUser(client, user.id);
      expect(after.quotaBalance).toBe(100);
    });
  });
});

describe("PgUserRepository.setSubscriptionProduct watermark", () => {
  it("ignores a stale event but accepts a newer one", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      const t1 = Date.now();
      const t0 = t1 - 60_000;

      // Apply newer event first.
      await repo.setSubscriptionProduct(user.id, MONTHLY, t1);
      let row = await fetchUser(client, user.id);
      expect(row.subscriptionProductId).toBe(MONTHLY);

      // Stale event should not overwrite to WEEKLY.
      await repo.setSubscriptionProduct(user.id, WEEKLY, t0);
      row = await fetchUser(client, user.id);
      expect(row.subscriptionProductId).toBe(MONTHLY);
    });
  });
});

describe("PgUserRepository.revokeImmediately", () => {
  it("clears is_premium AND subscription_product_id in one statement", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      await repo.setSubscriptionProduct(user.id, MONTHLY, Date.now());
      await repo.revokeImmediately(user.id, Date.now() + 1_000);

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(false);
      expect(after.subscriptionProductId).toBeNull();
      expect(after.gracePeriodUntil).toBeNull();
    });
  });
});

describe("PgUserRepository.setGracePeriod / clearGracePeriod", () => {
  it("set then clear leaves grace_period_until NULL", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      const grace = new Date(Date.now() + 7 * 24 * 60 * 60 * 1_000);
      await repo.setGracePeriod(user.id, grace, Date.now());
      let row = await fetchUser(client, user.id);
      expect(row.gracePeriodUntil).not.toBeNull();

      await repo.clearGracePeriod(user.id, Date.now() + 1_000);
      row = await fetchUser(client, user.id);
      expect(row.gracePeriodUntil).toBeNull();
    });
  });
});

describe("PgUserRepository.transferFrom (bug fix: clears product label)", () => {
  it("clears is_premium AND subscription_product_id for the original owner", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      await repo.setSubscriptionProduct(user.id, MONTHLY, Date.now());

      await repo.transferFrom([user.googleSub], Date.now() + 1_000);

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(false);
      // Before the fix this remained set to MONTHLY — purchase-flow.md §7 #4.
      expect(after.subscriptionProductId).toBeNull();
    });
  });
});

describe("PgUserRepository.transferTo", () => {
  it("sets is_premium and adopts the event's product_id, no quota credit", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      await repo.transferTo([user.googleSub], MONTHLY, Date.now());

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(true);
      expect(after.subscriptionProductId).toBe(MONTHLY);
      // Transfer moves entitlement, not balance. See purchase-flow.md §7 #4.
      expect(after.quotaBalance).toBe(0);
    });
  });
});

describe("PgUserRepository.hasSubscriptionTransactionForProduct", () => {
  it("returns true for matching subscription tx, false for unrelated product", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      await repo.creditQuota(user.id, 50, "subscription", MONTHLY, "evt-1");

      expect(await repo.hasSubscriptionTransactionForProduct(user.id, MONTHLY)).toBe(true);
      expect(await repo.hasSubscriptionTransactionForProduct(user.id, WEEKLY)).toBe(false);
    });
  });

  it("matches subscription_upgrade source too (PRODUCT_CHANGE credits)", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      await repo.creditQuota(user.id, 50, "subscription_upgrade", MONTHLY, "evt-upgrade");
      expect(await repo.hasSubscriptionTransactionForProduct(user.id, MONTHLY)).toBe(true);
    });
  });
});

describe("PgUserRepository.upsert", () => {
  it("returns created=true on first insert, created=false on subsequent upsert", async () => {
    await withTestTransaction(async (client) => {
      const repo = new PgUserRepository(client);
      const sub  = `test-upsert-${Date.now()}`;

      const first = await repo.upsert(sub, "a@example.com");
      expect(first.created).toBe(true);
      expect(first.user.email).toBe("a@example.com");

      const second = await repo.upsert(sub, "b@example.com");
      expect(second.created).toBe(false);
      expect(second.user.email).toBe("b@example.com"); // email updated
      expect(second.user.id).toBe(first.user.id);
    });
  });
});
