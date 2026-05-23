import { describe, it, expect } from "vitest";
import { PgUserRepository } from "../src/infrastructure/db/repositories/pg-user.repository";
import { withTestTransaction, createTestUser, fetchUser } from "./helpers/db";

describe("smoke — test infrastructure", () => {
  it("claimPremiumAndCredit flips premium and credits quota", async () => {
    await withTestTransaction(async (client) => {
      const user = await createTestUser(client);
      const repo = new PgUserRepository(client);

      const claimed = await repo.claimPremiumAndCredit(
        user.id,
        50,
        "GFM_Monthly_4.99",
        "subscription",
        "evt-smoke-1",
        Date.now(),
      );

      expect(claimed).toBe(true);

      const after = await fetchUser(client, user.id);
      expect(after.isPremium).toBe(true);
      expect(after.quotaBalance).toBe(50);
      expect(after.subscriptionProductId).toBe("GFM_Monthly_4.99");
      expect(after.lastEventAt).not.toBeNull();
    });
  });
});
