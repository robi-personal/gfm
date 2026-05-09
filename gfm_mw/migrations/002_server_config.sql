-- ============================================================
-- UP
-- ============================================================

-- ---- server_config ----
-- Mutable runtime configuration overrides. Keys mirror env.ts field names so
-- the admin API can write them through directly. Values are stored as TEXT and
-- coerced to the right shape (number/boolean) by ConfigService.

CREATE TABLE server_config (
  key         TEXT        PRIMARY KEY,
  value       TEXT        NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- DOWN
-- ============================================================
-- DROP TABLE IF EXISTS server_config;
