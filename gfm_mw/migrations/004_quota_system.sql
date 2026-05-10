-- ============================================================
-- Migration 002 — Quota System Redesign
-- Replaces per-tier counters with a single credit-balance model.
-- ============================================================

-- ── UP ────────────────────────────────────────────────────────────────────────

-- 1. Remove old tier counters; add new balance + grant columns
ALTER TABLE users
  DROP COLUMN IF EXISTS ai_free_used,
  DROP COLUMN IF EXISTS ai_premium_used,
  DROP COLUMN IF EXISTS free_month_reset_at,
  DROP COLUMN IF EXISTS premium_reset_at,
  ADD COLUMN IF NOT EXISTS quota_balance        INTEGER     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS free_quota_reset_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS subscription_product_id TEXT;

-- 2. Quota products catalogue
CREATE TABLE quota_products (
  product_id   TEXT        PRIMARY KEY,
  product_type TEXT        NOT NULL CHECK (product_type IN ('subscription', 'topup', 'free')),
  display_name TEXT        NOT NULL,
  quota_amount INTEGER     NOT NULL CHECK (quota_amount >= 0),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO quota_products (product_id, product_type, display_name, quota_amount, updated_at) VALUES
  ('free',         'free',         'Free Monthly',   3,   NOW()),
  ('gfm_weekly',   'subscription', 'Weekly Premium', 15,  NOW()),
  ('gfm_monthly',  'subscription', 'Monthly Premium',50,  NOW()),
  ('gfm_yearly',   'subscription', 'Yearly Premium', 700, NOW()),
  ('gfm_topup_10', 'topup',        'Top-up 10',      10,  NOW()),
  ('gfm_topup_20', 'topup',        'Top-up 20',      20,  NOW()),
  ('gfm_topup_30', 'topup',        'Top-up 30',      30,  NOW());

-- 3. Quota transactions audit log
CREATE TABLE quota_transactions (
  id            SERIAL      PRIMARY KEY,
  user_id       INTEGER     NOT NULL REFERENCES users (id),
  delta         INTEGER     NOT NULL,
  balance_after INTEGER     NOT NULL,
  source        TEXT        NOT NULL,
  product_id    TEXT        REFERENCES quota_products (product_id),
  ref_id        TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX quota_transactions_user_idx ON quota_transactions (user_id, created_at DESC);

-- 4. Whitelist table (keyed by email, case-insensitive)
CREATE TABLE quota_whitelist (
  email      TEXT        PRIMARY KEY,
  note       TEXT,
  added_by   TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO quota_whitelist (email, note, added_by)
VALUES ('robi.officee@gmail.com', 'developer — replaces is_premium bypass', 'system');

-- 5. Seed all existing users with the free monthly grant
UPDATE users SET quota_balance = (
  SELECT quota_amount FROM quota_products WHERE product_id = 'free'
);


-- ── DOWN ──────────────────────────────────────────────────────────────────────

-- DROP TABLE quota_whitelist;
-- DROP INDEX quota_transactions_user_idx;
-- DROP TABLE quota_transactions;
-- DROP TABLE quota_products;
-- ALTER TABLE users
--   DROP COLUMN IF EXISTS subscription_product_id,
--   DROP COLUMN IF EXISTS free_quota_reset_at,
--   DROP COLUMN IF EXISTS quota_balance,
--   ADD COLUMN IF NOT EXISTS ai_free_used        INTEGER NOT NULL DEFAULT 0,
--   ADD COLUMN IF NOT EXISTS ai_premium_used     INTEGER NOT NULL DEFAULT 0,
--   ADD COLUMN IF NOT EXISTS free_month_reset_at TIMESTAMPTZ,
--   ADD COLUMN IF NOT EXISTS premium_reset_at    TIMESTAMPTZ;
