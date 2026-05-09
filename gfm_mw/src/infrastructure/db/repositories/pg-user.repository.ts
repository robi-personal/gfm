import { User } from "../../../domain/entities/user.entity";
import { UserRepository } from "../../../domain/repositories/user.repository";
import { DbClient } from "../postgres";

function mapRow(row: Record<string, unknown>): User {
  return {
    id:               row["id"] as number,
    googleSub:        row["google_sub"] as string,
    email:            row["email"] as string,
    createdAt:        row["created_at"] as Date,
    isPremium:        row["is_premium"] as boolean,
    aiFreeUsed:       row["ai_free_used"] as number,
    aiPremiumUsed:    row["ai_premium_used"] as number,
    freeMonthResetAt: row["free_month_reset_at"] as Date | null,
    premiumResetAt:   row["premium_reset_at"] as Date | null,
    gracePeriodUntil:      row["grace_period_until"]       as Date | null,
    youtubeMinutesUsed:    (row["youtube_minutes_used"]    as number) ?? 0,
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

  async incrementFreeUsed(userId: number, by = 1): Promise<void> {
    // Set free_month_reset_at on first use (rolling 30-day window). See api-contract.md §4.3.
    await this.db.query(
      `UPDATE users SET
         ai_free_used        = ai_free_used + $2,
         free_month_reset_at = COALESCE(free_month_reset_at, NOW() + INTERVAL '30 days')
       WHERE id = $1`,
      [userId, by],
    );
  }

  async incrementPremiumUsed(userId: number, by = 1): Promise<void> {
    await this.db.query(
      "UPDATE users SET ai_premium_used = ai_premium_used + $2 WHERE id = $1",
      [userId, by],
    );
  }

  async resetFreeQuotaIfExpired(userId: number): Promise<void> {
    // Called on GET /user/status. Resets counter and clears reset date so the
    // next generation starts a fresh 30-day window. See api-contract.md §4.3.
    await this.db.query(
      `UPDATE users SET
         ai_free_used        = 0,
         free_month_reset_at = NULL
       WHERE id = $1
         AND free_month_reset_at IS NOT NULL
         AND free_month_reset_at < NOW()`,
      [userId],
    );
  }

  // ── RevenueCat event handlers ────────────────────────────────────────────────
  // All quota/premium writes use the "only advance, never retract" guard on
  // premium_reset_at to handle out-of-order RC delivery. See revenuecat-webhook-map.md §4.1.

  async setPremium(userId: number, premiumResetAt: Date): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium         = true,
         ai_premium_used    = 0,
         premium_reset_at   = $2,
         grace_period_until = NULL
       WHERE id = $1
         AND (premium_reset_at IS NULL OR $2 > premium_reset_at)`,
      [userId, premiumResetAt],
    );
  }

  async renewPremium(userId: number, premiumResetAt: Date): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium         = true,
         ai_premium_used    = 0,
         premium_reset_at   = $2,
         grace_period_until = NULL
       WHERE id = $1
         AND (premium_reset_at IS NULL OR $2 > premium_reset_at)`,
      [userId, premiumResetAt],
    );
  }

  async setGracePeriod(userId: number, gracePeriodUntil: Date): Promise<void> {
    // GREATEST guard: duplicate BILLING_ISSUE events only extend, never shorten.
    await this.db.query(
      `UPDATE users SET
         grace_period_until = GREATEST(grace_period_until, $2)
       WHERE id = $1`,
      [userId, gracePeriodUntil],
    );
  }

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

  async revokePremium(userId: number, eventExpiresAt: Date): Promise<void> {
    // Only revoke if no newer RENEWAL has already advanced premium_reset_at past
    // this event's expiry. Stale EXPIRATION events become no-ops.
    await this.db.query(
      `UPDATE users SET
         is_premium         = false,
         grace_period_until = NULL
       WHERE id = $1
         AND (premium_reset_at IS NULL OR premium_reset_at <= $2)`,
      [userId, eventExpiresAt],
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

  async updateProductChange(
    userId: number,
    isPremium: boolean,
    newResetAt: Date,
  ): Promise<void> {
    await this.db.query(
      `UPDATE users SET
         is_premium       = $2,
         premium_reset_at = CASE
           WHEN ($3::timestamptz > premium_reset_at OR premium_reset_at IS NULL)
           THEN $3::timestamptz
           ELSE premium_reset_at
         END
       WHERE id = $1`,
      [userId, isPremium, newResetAt],
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
