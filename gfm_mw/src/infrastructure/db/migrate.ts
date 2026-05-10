import { readFileSync } from "fs";
import { join } from "path";
import { pool } from "./postgres";
import { logger } from "../logger";

const MIGRATIONS_DIR = join(process.cwd(), "migrations");

const MIGRATIONS = [
  { id: "001", filename: "001_init.sql",             seededTable: "users" },
  { id: "002", filename: "002_server_config.sql",    seededTable: "server_config" },
  { id: "003", filename: "003_youtube_minutes.sql",  seededTable: "youtube_minutes_sentinel" },
  { id: "004", filename: "004_quota_system.sql",     seededTable: "quota_products" },
];

export async function runMigrations(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id          TEXT        PRIMARY KEY,
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  for (const { id, filename, seededTable } of MIGRATIONS) {
    const { rowCount } = await pool.query(
      "SELECT 1 FROM schema_migrations WHERE id = $1",
      [id],
    );
    if (rowCount && rowCount > 0) {
      logger.debug({ migration: id }, "migration_already_applied");
      continue;
    }

    // If the table already exists (e.g. seeded by docker-entrypoint-initdb.d), mark as applied.
    const { rowCount: tableExists } = await pool.query(
      "SELECT 1 FROM information_schema.tables WHERE table_name = $1 AND table_schema = 'public'",
      [seededTable],
    );
    if (tableExists && tableExists > 0) {
      await pool.query("INSERT INTO schema_migrations (id) VALUES ($1)", [id]);
      logger.info({ migration: id }, "migration_already_seeded_by_initdb");
      continue;
    }

    const sql = readFileSync(join(MIGRATIONS_DIR, filename), "utf-8");
    // Strip the DOWN section (it is all comments, but trim for clarity)
    const upSql = sql.split("-- ============================================================\n-- DOWN")[0];

    await pool.query(upSql);
    await pool.query("INSERT INTO schema_migrations (id) VALUES ($1)", [id]);
    logger.info({ migration: id }, "migration_applied");
  }
}
