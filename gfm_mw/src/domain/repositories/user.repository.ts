import { User } from "../entities/user.entity";
import { QuotaProduct } from "../entities/quota-product";

export interface UserRepository {
  findByGoogleSub(googleSub: string): Promise<User | null>;
  findById(id: number): Promise<User | null>;
  upsert(googleSub: string, email: string): Promise<User>;

  // Quota balance
  creditQuota(
    userId: number,
    amount: number,
    source: string,
    productId?: string,
    refId?: string,
  ): Promise<void>;
  debitQuota(userId: number, amount: number, refId: string): Promise<void>;
  applyFreeGrantIfDue(userId: number, freeProduct: QuotaProduct): Promise<void>;
  getQuotaBalance(userId: number): Promise<number>;
  setSubscriptionProduct(userId: number, productId: string | null): Promise<void>;
  /**
   * Atomically flip is_premium → true, set subscription product, and credit
   * quota. Returns true if this caller claimed (rows affected > 0), false if
   * the user was already premium (another path — webhook or sync — won the
   * race). Used to dedupe concurrent INITIAL_PURCHASE webhook and
   * /user/purchase/sync paths.
   */
  claimPremiumAndCredit(
    userId: number,
    amount: number,
    productId: string,
    source: string,
    refId: string,
  ): Promise<boolean>;

  // YouTube minute cap
  incrementYoutubeMinutes(userId: number, minutes: number): Promise<void>;
  resetYoutubeMinutesIfNeeded(userId: number): Promise<void>;

  // RevenueCat event handlers
  setPremium(userId: number, premiumResetAt: Date): Promise<void>;
  renewPremium(userId: number, premiumResetAt: Date): Promise<void>;
  setGracePeriod(userId: number, gracePeriodUntil: Date): Promise<void>;
  revokePremium(userId: number, eventExpiresAt: Date): Promise<void>;
  revokeImmediately(userId: number): Promise<void>;
  updateProductChange(userId: number, isPremium: boolean, newResetAt: Date): Promise<void>;
  transferFrom(googleSubs: string[]): Promise<void>;
  transferTo(googleSubs: string[]): Promise<void>;
}
