import { readFileSync } from "fs";
import { join } from "path";
import { pool } from "./postgres";
import { logger } from "../logger";

const MIGRATIONS_DIR = join(process.cwd(), "migrations");

const MIGRATIONS = [{ id: "001", filename: "001_init.sql" }];

export async function runMigrations(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id          TEXT        PRIMARY KEY,
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  for (const { id, filename } of MIGRATIONS) {
    const { rowCount } = await pool.query(
      "SELECT 1 FROM schema_migrations WHERE id = $1",
      [id],
    );
    if (rowCount && rowCount > 0) {
      logger.debug({ migration: id }, "migration_already_applied");
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
