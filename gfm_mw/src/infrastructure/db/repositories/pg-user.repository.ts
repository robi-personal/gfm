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

// Out-of-order RC delivery guard. NULL caller timestamp means "non-webhook
// caller, skip the check" (sync, free grant). NULL row value means "no event
// has ever advanced this row" — first event wins. `<=` not `<` so chained
// UPDATEs inside one handler (e.g. RENEWAL: setSubscriptionProduct +
// clearGracePeriod with the same event ts) all apply; duplicate-event
// protection lives one layer up at webhook_events.event_id UNIQUE.
// See purchase-flow.md §6.3.
const WATERMARK_CLAUSE =
  "(($ts::bigint IS NULL) OR last_event_at IS NULL OR last_event_at <= to_timestamp($ts::bigint / 1000.0))";

function tsParam(eventTimestampMs: number | null): number | null {
  return eventTimestampMs ?? null;
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

  async upsert(googleSub: string, email: string): Promise<{ user: User; created: boolean }> {
    // xmax = '0' on a freshly-inserted row; non-zero on an UPDATE conflict path.
    // Lets the caller (auth.middleware) trigger orphan-webhook replay on first sign-in.
    const { rows } = await this.db.query(
      `INSERT INTO users (google_sub, email)
       VALUES ($1, $2)
       ON CONFLICT (google_sub) DO UPDATE SET email = EXCLUDED.email
       RETURNING *, (xmax = 0) AS created`,
      [googleSub, email],
    );
    return { user: mapRow(rows[0]), created: rows[0]["created"] === true };
  }

  // ── Quota balance ────────────────────────────────────────────────────────────

  async creditQuota(
    userId: number,
    amount: number,
    source: string,
    productId?: string,
    refId?: string,
  ): Promise<void> {
    // Step 1: claim the dedup slot. ON CONFLICT DO NOTHING makes this
    // idempotent on (user_id, source, product_id, ref_id) via the partial
    // unique index from migration 007. Bail early on duplicate — no credit.
    const { rows } = await this.db.query(
      `INSERT INTO quota_transactions (user_id, delta, balance_after, source, product_id, ref_id)
       VALUES ($1, $2, 0, $3, $4, $5)
       ON CONFLICT (user_id, source, product_id, ref_id)
         WHERE ref_id IS NOT NULL DO NOTHING
       RETURNING id`,
      [userId, amount, source, productId ?? null, refId ?? null],
    );
    if (rows.length === 0) return;

    // Step 2: apply the credit and capture the new running balance.
    // PG CTE snapshot isolation prevents the primary query of a WITH statement
    // from seeing rows inserted by a sibling CTE via a table scan — so the
    // original single-statement approach always wrote balance_after=0.
    const { rows: updated } = await this.db.query(
      `UPDATE users SET quota_balance = quota_balance + $2
       WHERE id = $1
       RETURNING quota_balance`,
      [userId, amount],
    );

    // Step 3: patch the audit row with the correct running balance.
    if (updated.length > 0) {
      await this.db.query(
        `UPDATE quota_transactions SET balance_after = $2 WHERE id = $1`,
        [rows[0]["id"] as number, updated[0]["quota_balance"] as number],
      );
    }
  }

  async hasSubscriptionTransactionForProduct(userId: number, productId: string): Promise<boolean> {
    const { rows } = await this.db.query(
      `SELECT 1 FROM quota_transactions
       WHERE user_id = $1
         AND product_id = $2
         AND source IN ('subscription', 'subscription_upgrade')
       LIMIT 1`,
      [userId, productId],
    );
    return rows.length > 0;
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

  async setSubscriptionProduct(
    userId: number,
    productId: string | null,
    eventTimestampMs: number | null,
  ): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         subscription_product_id = $2::text,
         is_premium              = ($2::text IS NOT NULL),
         last_event_at           = COALESCE(to_timestamp($3::bigint / 1000.0), last_event_at)
       WHERE id = $1
         AND ${WATERMARK_CLAUSE.replaceAll("$ts", "$3")}`,
      [userId, productId, tsParam(eventTimestampMs)],
    );
  }

  async claimPremiumAndCredit(
    userId: number,
    amount: number,
    productId: string,
    source: string,
    refId: string,
    eventTimestampMs: number | null,
  ): Promise<boolean> {
    // The `is_premium = FALSE` guard atomizes the INITIAL_PURCHASE claim across
    // concurrent webhook + sync callers. The watermark clause additionally
    // rejects late-arriving INITIAL_PURCHASE events (e.g. after EXPIRATION).
    // See purchase-flow.md §6.1 and §6.3.
    const { rows } = await this.db.query(
      `WITH claimed AS (
         UPDATE users
         SET
           quota_balance           = quota_balance + $2,
           subscription_product_id = $3,
           is_premium              = TRUE,
           last_event_at           = COALESCE(to_timestamp($6::bigint / 1000.0), last_event_at)
         WHERE id = $1
           AND is_premium = FALSE
           AND ${WATERMARK_CLAUSE.replaceAll("$ts", "$6")}
         RETURNING quota_balance
       ), tx AS (
         INSERT INTO quota_transactions
           (user_id, delta, balance_after, source, product_id, ref_id)
         SELECT $1, $2, quota_balance, $4, $3, $5 FROM claimed
         ON CONFLICT (user_id, source, product_id, ref_id)
           WHERE ref_id IS NOT NULL DO NOTHING
         RETURNING 1
       )
       SELECT EXISTS (SELECT 1 FROM claimed) AS claimed`,
      [userId, amount, productId, source, refId, tsParam(eventTimestampMs)],
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
  // All premium-state writes carry the watermark guard so a late event can never
  // retract or duplicate a more recent one. See purchase-flow.md §6.3.

  async setGracePeriod(
    userId: number,
    gracePeriodUntil: Date,
    eventTimestampMs: number | null,
  ): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         grace_period_until = GREATEST(grace_period_until, $2),
         last_event_at      = COALESCE(to_timestamp($3::bigint / 1000.0), last_event_at)
       WHERE id = $1
         AND ${WATERMARK_CLAUSE.replaceAll("$ts", "$3")}`,
      [userId, gracePeriodUntil, tsParam(eventTimestampMs)],
    );
  }

  async clearGracePeriod(userId: number, eventTimestampMs: number | null): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         grace_period_until = NULL,
         last_event_at      = COALESCE(to_timestamp($2::bigint / 1000.0), last_event_at)
       WHERE id = $1
         AND ${WATERMARK_CLAUSE.replaceAll("$ts", "$2")}`,
      [userId, tsParam(eventTimestampMs)],
    );
  }

  async revokeImmediately(userId: number, eventTimestampMs: number | null): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium              = FALSE,
         grace_period_until      = NULL,
         subscription_product_id = NULL,
         last_event_at           = COALESCE(to_timestamp($2::bigint / 1000.0), last_event_at)
       WHERE id = $1
         AND ${WATERMARK_CLAUSE.replaceAll("$ts", "$2")}`,
      [userId, tsParam(eventTimestampMs)],
    );
  }

  async updateProductChange(
    userId: number,
    isPremium: boolean,
    eventTimestampMs: number | null,
  ): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium    = $2,
         last_event_at = COALESCE(to_timestamp($3::bigint / 1000.0), last_event_at)
       WHERE id = $1
         AND ${WATERMARK_CLAUSE.replaceAll("$ts", "$3")}`,
      [userId, isPremium, tsParam(eventTimestampMs)],
    );
  }

  async transferFrom(googleSubs: string[], eventTimestampMs: number | null): Promise<void> {
    if (googleSubs.length === 0) return;
    // Clear subscription_product_id too — leaving it set on a transferred-away
    // user is the bug the doc §7 used to flag. Quota balance is not clawed back.
    await this.db.query(
      `UPDATE users SET
         is_premium              = FALSE,
         grace_period_until      = NULL,
         subscription_product_id = NULL,
         last_event_at           = COALESCE(to_timestamp($2::bigint / 1000.0), last_event_at)
       WHERE google_sub = ANY($1::text[])
         AND ${WATERMARK_CLAUSE.replaceAll("$ts", "$2")}`,
      [googleSubs, tsParam(eventTimestampMs)],
    );
  }

  async transferTo(
    googleSubs: string[],
    productId: string | null,
    eventTimestampMs: number | null,
  ): Promise<void> {
    if (googleSubs.length === 0) return;
    // Receiver gets premium + product label, but no quota credit (per
    // purchase-flow.md §7 decision: transfer moves entitlement, not balance).
    await this.db.query(
      `UPDATE users SET
         is_premium              = TRUE,
         subscription_product_id = COALESCE($2::text, subscription_product_id),
         last_event_at           = COALESCE(to_timestamp($3::bigint / 1000.0), last_event_at)
       WHERE google_sub = ANY($1::text[])
         AND ${WATERMARK_CLAUSE.replaceAll("$ts", "$3")}`,
      [googleSubs, productId, tsParam(eventTimestampMs)],
    );
  }
}
