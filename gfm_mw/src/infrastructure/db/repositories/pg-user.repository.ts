import { User } from "../../../domain/entities/user.entity";
import { QuotaProduct } from "../../../domain/entities/quota-product";
import { UserRepository } from "../../../domain/repositories/user.repository";
import { DbClient } from "../postgres";

function mapRow(row: Record<string, unknown>): User {
  return {
    id:                    row["id"]                     as number,
    googleSub:             row["google_sub"]             as string,
    email:                 row["email"]                  as string,
    createdAt:             row["created_at"]             as Date,
    isPremium:             row["is_premium"]             as boolean,
    quotaBalance:          (row["quota_balance"]         as number) ?? 0,
    freeQuotaResetAt:      row["free_quota_reset_at"]    as Date | null,
    subscriptionProductId: row["subscription_product_id"] as string | null,
    gracePeriodUntil:      row["grace_period_until"]     as Date | null,
    youtubeMinutesUsed:    (row["youtube_minutes_used"]  as number) ?? 0,
    youtubeMinutesResetAt: row["youtube_minutes_reset_at"] as Date | null,
  };
}

export class PgUserRepository implements UserRepository {
  constructor(private readonly db: DbClient) {}

  async findByGoogleSub(googleSub: string): Promise<User | null> {
    const { rows } = await this.db.query(
      "SELECT * FROM users WHERE google_sub = $1",
      [googleSub],
    );
    return rows[0] ? mapRow(rows[0]) : null;
  }

  async findById(id: number): Promise<User | null> {
    const { rows } = await this.db.query(
      "SELECT * FROM users WHERE id = $1",
      [id],
    );
    return rows[0] ? mapRow(rows[0]) : null;
  }

  async upsert(googleSub: string, email: string): Promise<User> {
    const { rows } = await this.db.query(
      `INSERT INTO users (google_sub, email)
       VALUES ($1, $2)
       ON CONFLICT (google_sub) DO UPDATE SET email = EXCLUDED.email
       RETURNING *`,
      [googleSub, email],
    );
    return mapRow(rows[0]);
  }

  // ── Quota balance ────────────────────────────────────────────────────────────

  async creditQuota(
    userId: number,
    amount: number,
    source: string,
    productId?: string,
    refId?: string,
  ): Promise<void> {
    await this.db.query(
      `WITH updated AS (
         UPDATE users SET quota_balance = quota_balance + $2 WHERE id = $1
         RETURNING quota_balance
       )
       INSERT INTO quota_transactions (user_id, delta, balance_after, source, product_id, ref_id)
       SELECT $1, $2, quota_balance, $3, $4, $5 FROM updated`,
      [userId, amount, source, productId ?? null, refId ?? null],
    );
  }

  async debitQuota(userId: number, amount: number, refId: string): Promise<void> {
    // Guard: only debit if balance covers the cost. Generation gate prevents reaching
    // here with an insufficient balance, so this check is a safety net for races.
    await this.db.query(
      `WITH updated AS (
         UPDATE users SET quota_balance = quota_balance - $2
         WHERE id = $1 AND quota_balance >= $2
         RETURNING quota_balance
       )
       INSERT INTO quota_transactions (user_id, delta, balance_after, source, product_id, ref_id)
       SELECT $1, -$2, quota_balance, 'generation', NULL, $3 FROM updated`,
      [userId, amount, refId],
    );
  }

  async applyFreeGrantIfDue(userId: number, freeProduct: QuotaProduct): Promise<void> {
    // Conditional UPDATE: only credits if the grant window has elapsed.
    // Concurrent requests: the first UPDATE to win sets the next reset timestamp,
    // subsequent concurrent rows see the future timestamp and skip — no double-credit.
    await this.db.query(
      `WITH updated AS (
         UPDATE users
         SET
           quota_balance       = quota_balance + $2,
           free_quota_reset_at = NOW() + INTERVAL '30 days'
         WHERE id = $1
           AND (free_quota_reset_at IS NULL OR free_quota_reset_at <= NOW())
         RETURNING quota_balance
       )
       INSERT INTO quota_transactions (user_id, delta, balance_after, source, product_id, ref_id)
       SELECT $1, $2, quota_balance, 'free_grant', $3, NULL FROM updated`,
      [userId, freeProduct.quotaAmount, freeProduct.productId],
    );
  }

  async getQuotaBalance(userId: number): Promise<number> {
    const { rows } = await this.db.query(
      "SELECT quota_balance FROM users WHERE id = $1",
      [userId],
    );
    return (rows[0]?.["quota_balance"] as number) ?? 0;
  }

  async setSubscriptionProduct(userId: number, productId: string | null): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         subscription_product_id = $2,
         is_premium              = ($2 IS NOT NULL)
       WHERE id = $1`,
      [userId, productId],
    );
  }

  async claimPremiumAndCredit(
    userId: number,
    amount: number,
    productId: string,
    source: string,
    refId: string,
  ): Promise<boolean> {
    // The `WHERE is_premium = false` guard makes this a single atomic claim:
    // only one of two concurrent callers (webhook INITIAL_PURCHASE + sync) will
    // see rows returned from the UPDATE, so the quota_transactions INSERT also
    // runs at most once.
    const { rows } = await this.db.query(
      `WITH claimed AS (
         UPDATE users
         SET
           quota_balance           = quota_balance + $2,
           subscription_product_id = $3,
           is_premium              = TRUE
         WHERE id = $1 AND is_premium = FALSE
         RETURNING quota_balance
       ), tx AS (
         INSERT INTO quota_transactions
           (user_id, delta, balance_after, source, product_id, ref_id)
         SELECT $1, $2, quota_balance, $4, $3, $5 FROM claimed
         RETURNING 1
       )
       SELECT EXISTS (SELECT 1 FROM claimed) AS claimed`,
      [userId, amount, productId, source, refId],
    );
    return rows[0]?.["claimed"] === true;
  }

  // ── YouTube minute cap ────────────────────────────────────────────────────────

  async incrementYoutubeMinutes(userId: number, minutes: number): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         youtube_minutes_used     = youtube_minutes_used + $2,
         youtube_minutes_reset_at = COALESCE(youtube_minutes_reset_at, NOW() + INTERVAL '30 days')
       WHERE id = $1`,
      [userId, minutes],
    );
  }

  async resetYoutubeMinutesIfNeeded(userId: number): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         youtube_minutes_used     = 0,
         youtube_minutes_reset_at = NULL
       WHERE id = $1
         AND youtube_minutes_reset_at IS NOT NULL
         AND youtube_minutes_reset_at < NOW()`,
      [userId],
    );
  }

  // ── RevenueCat event handlers ────────────────────────────────────────────────
  // All premium writes use the "only advance, never retract" guard on premium_reset_at
  // to handle out-of-order RC delivery. See revenuecat-webhook-map.md §4.1.

  // premiumResetAt is accepted for interface compatibility but no longer stored
  // — subscription tracking is handled by setSubscriptionProduct.
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async setPremium(userId: number, _premiumResetAt: Date): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium         = true,
         grace_period_until = NULL
       WHERE id = $1`,
      [userId],
    );
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async renewPremium(userId: number, _premiumResetAt: Date): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium         = true,
         grace_period_until = NULL
       WHERE id = $1`,
      [userId],
    );
  }

  async setGracePeriod(userId: number, gracePeriodUntil: Date): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         grace_period_until = GREATEST(grace_period_until, $2)
       WHERE id = $1`,
      [userId, gracePeriodUntil],
    );
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async revokePremium(userId: number, _eventExpiresAt: Date): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium         = false,
         grace_period_until = NULL
       WHERE id = $1`,
      [userId],
    );
  }

  async revokeImmediately(userId: number): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium         = false,
         grace_period_until = NULL
       WHERE id = $1`,
      [userId],
    );
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async updateProductChange(userId: number, isPremium: boolean, _newResetAt: Date): Promise<void> {
    await this.db.query(
      "UPDATE users SET is_premium = $2 WHERE id = $1",
      [userId, isPremium],
    );
  }

  async transferFrom(googleSubs: string[]): Promise<void> {
    if (googleSubs.length === 0) return;
    await this.db.query(
      `UPDATE users SET
         is_premium         = false,
         grace_period_until = NULL
       WHERE google_sub = ANY($1::text[])`,
      [googleSubs],
    );
  }

  async transferTo(googleSubs: string[]): Promise<void> {
    if (googleSubs.length === 0) return;
    await this.db.query(
      "UPDATE users SET is_premium = true WHERE google_sub = ANY($1::text[])",
      [googleSubs],
    );
  }
}
