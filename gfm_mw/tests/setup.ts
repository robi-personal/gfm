/**
 * Vitest global setup — runs once before any test file.
 *
 * 1. Creates the `gfm_test` database on the local Postgres instance
 *    if it doesn't exist (connects via the admin `postgres` DB).
 * 2. Runs every migration registered in src/infrastructure/db/migrate.ts
 *    against gfm_test. The singleton `pool` in postgres.ts already
 *    points at gfm_test via DATABASE_URL in vitest.config.ts.
 *
 * Migrations are idempotent via schema_migrations.id tracking, so this
 * is cheap on repeat runs.
 */
import { Pool } from "pg";

async function ensureTestDatabaseExists(): Promise<void> {
  const adminPool = new Pool({
    connectionString: "postgres://gfm:gfm@localhost:5432/postgres",
  });
  try {
    const { rows } = await adminPool.query(
      "SELECT 1 FROM pg_database WHERE datname = 'gfm_test'",
    );
    if (rows.length === 0) {
      await adminPool.query("CREATE DATABASE gfm_test");
      // eslint-disable-next-line no-console
      console.log("[tests/setup] Created gfm_test database");
    }
  } finally {
    await adminPool.end();
  }
}

async function applyMigrations(): Promise<void> {
  const { runMigrations } = await import("../src/infrastructure/db/migrate");
  await runMigrations();
}

await ensureTestDatabaseExists();
await applyMigrations();
