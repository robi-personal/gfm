import { User } from "../entities/user.entity";
import { QuotaProduct } from "../entities/quota-product";

/**
 * `eventTimestampMs` on RC-driven methods is the watermark from
 * `event.event_timestamp_ms` (or `purchased_at_ms` as fallback). It guards
 * against out-of-order RC delivery: the UPDATE only fires when the row's
 * `last_event_at` is older than the incoming event. Pass `null` from
 * non-webhook callers (sync, free-grant) to bypass the watermark check.
 *
 * See purchase-flow.md §6.3 for the corruption modes this prevents.
 */
export interface UserRepository {
  findByGoogleSub(googleSub: string): Promise<User | null>;
  findById(id: number): Promise<User | null>;
  upsert(googleSub: string, email: string): Promise<{ user: User; created: boolean }>;

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
  hasSubscriptionTransactionForProduct(userId: number, productId: string): Promise<boolean>;
  setSubscriptionProduct(
    userId: number,
    productId: string | null,
    eventTimestampMs: number | null,
  ): Promise<void>;
  /**
   * Atomically flip is_premium → true, set subscription product, and credit
   * quota. Returns true if this caller claimed (rows affected > 0), false if
   * the user was already premium (another path — webhook or sync — won the
   * race). Used to dedupe concurrent INITIAL_PURCHASE webhook and
   * /user/purchase/sync paths.
   *
   * Also enforces the watermark guard when `eventTimestampMs` is supplied.
   */
  claimPremiumAndCredit(
    userId: number,
    amount: number,
    productId: string,
    source: string,
    refId: string,
    eventTimestampMs: number | null,
  ): Promise<boolean>;

  // YouTube minute cap
  incrementYoutubeMinutes(userId: number, minutes: number): Promise<void>;
  resetYoutubeMinutesIfNeeded(userId: number): Promise<void>;

  // RevenueCat event handlers
  setGracePeriod(
    userId: number,
    gracePeriodUntil: Date,
    eventTimestampMs: number | null,
  ): Promise<void>;
  clearGracePeriod(userId: number, eventTimestampMs: number | null): Promise<void>;
  revokeImmediately(userId: number, eventTimestampMs: number | null): Promise<void>;
  updateProductChange(
    userId: number,
    isPremium: boolean,
    eventTimestampMs: number | null,
  ): Promise<void>;
  transferFrom(googleSubs: string[], eventTimestampMs: number | null): Promise<void>;
  transferTo(
    googleSubs: string[],
    productId: string | null,
    eventTimestampMs: number | null,
  ): Promise<void>;
}
