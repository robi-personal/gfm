import type { PoolClient } from "pg";
import { pool } from "../../src/infrastructure/db/postgres";

/**
 * Runs `fn` inside a transaction that is ALWAYS rolled back, so the test
 * commits nothing. The PoolClient handed to `fn` is the same one the
 * transaction is open on — pass it to repository constructors so their
 * SQL participates in the rollback.
 */
export async function withTestTransaction(
  fn: (client: PoolClient) => Promise<void>,
): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    try {
      await fn(client);
    } finally {
      // Always roll back — even on assertion failure. Releases any locks
      // and leaves the DB clean for the next test.
      await client.query("ROLLBACK");
    }
  } finally {
    client.release();
  }
}

export interface TestUser {
  id: number;
  googleSub: string;
  email: string;
}

let userCounter = 0;

/**
 * Inserts a fresh users row inside the test transaction. The google_sub
 * is unique-per-call so concurrent tests (and re-runs) don't collide.
 */
export async function createTestUser(
  client: PoolClient,
  opts: { googleSub?: string; email?: string } = {},
): Promise<TestUser> {
  const counter = ++userCounter;
  const googleSub = opts.googleSub ?? `test-sub-${Date.now()}-${counter}`;
  const email     = opts.email     ?? `${googleSub}@test.example`;
  const { rows } = await client.query(
    `INSERT INTO users (google_sub, email)
     VALUES ($1, $2)
     RETURNING id, google_sub, email`,
    [googleSub, email],
  );
  return { id: rows[0]["id"], googleSub: rows[0]["google_sub"], email: rows[0]["email"] };
}

/**
 * Fetches the current users row for assertions.
 */
export async function fetchUser(client: PoolClient, userId: number): Promise<{
  isPremium: boolean;
  quotaBalance: number;
  subscriptionProductId: string | null;
  gracePeriodUntil: Date | null;
  lastEventAt: Date | null;
}> {
  const { rows } = await client.query(
    `SELECT is_premium, quota_balance, subscription_product_id,
            grace_period_until, last_event_at
       FROM users WHERE id = $1`,
    [userId],
  );
  return {
    isPremium:             rows[0]["is_premium"],
    quotaBalance:          rows[0]["quota_balance"],
    subscriptionProductId: rows[0]["subscription_product_id"],
    gracePeriodUntil:      rows[0]["grace_period_until"],
    lastEventAt:           rows[0]["last_event_at"],
  };
}

/**
 * Returns all quota_transactions rows for a user, newest first.
 */
export async function fetchTransactions(client: PoolClient, userId: number): Promise<Array<{
  delta: number;
  balanceAfter: number;
  source: string;
  productId: string | null;
  refId: string | null;
}>> {
  const { rows } = await client.query(
    `SELECT delta, balance_after, source, product_id, ref_id
       FROM quota_transactions WHERE user_id = $1
       ORDER BY id DESC`,
    [userId],
  );
  return rows.map((r) => ({
    delta:        r["delta"],
    balanceAfter: r["balance_after"],
    source:       r["source"],
    productId:    r["product_id"],
    refId:        r["ref_id"],
  }));
}
