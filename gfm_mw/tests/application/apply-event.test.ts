/**
 * applyEvent handler tests — one case per RC event type, asserting the
 * end-to-end effect on users + quota_transactions. Catches regressions to
 * the switch statement in src/application/rc-webhook/apply-event.ts.
 */
import { describe, it, expect } from "vitest";
import { applyEvent, type RcEvent } from "../../src/application/rc-webhook/apply-event";
import {
  withTestTransaction,
  createTestUser,
  fetchUser,
  fetchTransactions,
} from "../helpers/db";

const MONTHLY = "GFM_Monthly_4.99";
const WEEKLY  = "GFM_Weekly_3.99";
const TOPUP   = "gfm_topup_10";

function rcEvent(partial: Partial<RcEvent> & { id: string; type: string; app_user_id: string }): RcEvent {
  return {
    environment:        "PRODUCTION",
    event_timestamp_ms: Date.now(),
    ...partial,
  };
}

describe("applyEvent: INITIAL_PURCHASE", () => {
  it("flips premium, sets product, credits quota, writes one tx with ref_id=event.id", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      await applyEvent(client, user.id, rcEvent({
        id: "evt-init-1", type: "INITIAL_PURCHASE",
        app_user_id: user.googleSub, product_id: MONTHLY,
      }));

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(true);
      expect(after.subscriptionProductId).toBe(MONTHLY);
      expect(after.quotaBalance).toBe(50);

      const txs = await fetchTransactions(client, user.id);
      expect(txs).toHaveLength(1);
      expect(txs[0].refId).toBe("evt-init-1");
      expect(txs[0].source).toBe("subscription");
    });
  });

  it("logs and no-ops when product_id missing (no DB write)", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      await applyEvent(client, user.id, rcEvent({
        id: "evt-init-bad", type: "INITIAL_PURCHASE",
        app_user_id: user.googleSub,
        // product_id intentionally omitted
      }));

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(false);
      expect(after.quotaBalance).toBe(0);
    });
  });
});

describe("applyEvent: RENEWAL", () => {
  it("credits new quota and clears any prior grace period", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);

      // Seed state: user is in BILLING_ISSUE grace.
      await applyEvent(client, user.id, rcEvent({
        id: "evt-billing-1", type: "BILLING_ISSUE",
        app_user_id: user.googleSub,
        grace_period_expiration_at_ms: Date.now() + 5 * 24 * 60 * 60 * 1_000,
        event_timestamp_ms: Date.now() - 1_000,
      }));
      let row = await fetchUser(client, user.id);
      expect(row.gracePeriodUntil).not.toBeNull();

      // Successful RENEWAL clears the grace.
      await applyEvent(client, user.id, rcEvent({
        id: "evt-renewal-1", type: "RENEWAL",
        app_user_id: user.googleSub, product_id: MONTHLY,
      }));

      row = await fetchUser(client, user.id);
      expect(row.gracePeriodUntil).toBeNull();
      expect(row.subscriptionProductId).toBe(MONTHLY);
      expect(row.quotaBalance).toBe(50);
    });
  });
});

describe("applyEvent: REFUND", () => {
  it("revokes premium, clears product, keeps quota_balance (audit-only)", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      // Seed: previous INITIAL_PURCHASE credited 50.
      await applyEvent(client, user.id, rcEvent({
        id: "evt-init-2", type: "INITIAL_PURCHASE",
        app_user_id: user.googleSub, product_id: MONTHLY,
        event_timestamp_ms: Date.now() - 1_000,
      }));

      await applyEvent(client, user.id, rcEvent({
        id: "evt-refund-1", type: "REFUND",
        app_user_id: user.googleSub,
      }));

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(false);
      expect(after.subscriptionProductId).toBeNull();
      // Quota stays — REFUND is audit-only on balance per purchase-flow.md.
      expect(after.quotaBalance).toBe(50);
    });
  });
});

describe("applyEvent: PRODUCT_CHANGE", () => {
  it("credits the new product as subscription_upgrade and updates product_id", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      await applyEvent(client, user.id, rcEvent({
        id: "evt-init-3", type: "INITIAL_PURCHASE",
        app_user_id: user.googleSub, product_id: WEEKLY,
        event_timestamp_ms: Date.now() - 1_000,
      }));

      await applyEvent(client, user.id, rcEvent({
        id: "evt-change-1", type: "PRODUCT_CHANGE",
        app_user_id: user.googleSub, product_id: MONTHLY,
        entitlement_ids: ["GFMPremium"],
      }));

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(true);
      expect(after.subscriptionProductId).toBe(MONTHLY);
      // Weekly (15) + Monthly upgrade (50) = 65.
      expect(after.quotaBalance).toBe(65);

      const txs = await fetchTransactions(client, user.id);
      expect(txs[0].source).toBe("subscription_upgrade");
      expect(txs[0].productId).toBe(MONTHLY);
    });
  });
});

describe("applyEvent: NON_RENEWING_PURCHASE", () => {
  it("credits topup without touching premium status", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      await applyEvent(client, user.id, rcEvent({
        id: "evt-topup-1", type: "NON_RENEWING_PURCHASE",
        app_user_id: user.googleSub, product_id: TOPUP,
      }));

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(false);
      expect(after.subscriptionProductId).toBeNull();
      expect(after.quotaBalance).toBe(10);

      const txs = await fetchTransactions(client, user.id);
      expect(txs[0].source).toBe("topup");
    });
  });
});

describe("applyEvent: EXPIRATION", () => {
  it("clears premium status but preserves quota_balance", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      await applyEvent(client, user.id, rcEvent({
        id: "evt-init-4", type: "INITIAL_PURCHASE",
        app_user_id: user.googleSub, product_id: MONTHLY,
        event_timestamp_ms: Date.now() - 1_000,
      }));

      await applyEvent(client, user.id, rcEvent({
        id: "evt-expire-1", type: "EXPIRATION",
        app_user_id: user.googleSub,
      }));

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(false);
      expect(after.subscriptionProductId).toBeNull();
      expect(after.quotaBalance).toBe(50);
    });
  });
});

describe("applyEvent: CANCELLATION", () => {
  it("is a no-op — subscription stays active until EXPIRATION", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      await applyEvent(client, user.id, rcEvent({
        id: "evt-init-5", type: "INITIAL_PURCHASE",
        app_user_id: user.googleSub, product_id: MONTHLY,
        event_timestamp_ms: Date.now() - 1_000,
      }));
      const before = await fetchUser(client, user.id);

      await applyEvent(client, user.id, rcEvent({
        id: "evt-cancel-1", type: "CANCELLATION",
        app_user_id: user.googleSub,
      }));

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(before.isPremium);
      expect(after.subscriptionProductId).toBe(before.subscriptionProductId);
      expect(after.quotaBalance).toBe(before.quotaBalance);
    });
  });
});

describe("applyEvent: out-of-order delivery", () => {
  it("late RENEWAL after REFUND does not reactivate (watermark + dedupe)", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const t0 = Date.now() - 10_000;
      const t1 = Date.now() - 5_000;
      const t2 = Date.now();

      await applyEvent(client, user.id, rcEvent({
        id: "evt-init-6", type: "INITIAL_PURCHASE",
        app_user_id: user.googleSub, product_id: MONTHLY,
        event_timestamp_ms: t0,
      }));

      // REFUND with newer timestamp.
      await applyEvent(client, user.id, rcEvent({
        id: "evt-refund-2", type: "REFUND",
        app_user_id: user.googleSub,
        event_timestamp_ms: t2,
      }));

      // Late RENEWAL with older timestamp arrives AFTER refund.
      await applyEvent(client, user.id, rcEvent({
        id: "evt-renewal-late", type: "RENEWAL",
        app_user_id: user.googleSub, product_id: MONTHLY,
        event_timestamp_ms: t1,
      }));

      const after = await fetchUser(client, user.id);
      // Premium stays revoked — setSubscriptionProduct's watermark blocks
      // the late RENEWAL from re-asserting premium.
      expect(after.isPremium).toBe(false);
      expect(after.subscriptionProductId).toBeNull();
      // creditQuota itself has no watermark, but the credit lands because
      // ref_id differs from the INITIAL — that's by design (each event_id
      // is a distinct credit). The intent of the watermark is to protect
      // PREMIUM STATE, not the audit log.
    });
  });
});
