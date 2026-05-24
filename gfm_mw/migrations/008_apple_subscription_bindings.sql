-- ============================================================
-- Migration 008 — Apple subscription bindings
--   One Apple original_transaction_id → one Google account (user_id),
--   permanently. Prevents one Apple subscription from crediting quota
--   across multiple Google accounts.
-- ============================================================

-- ── UP ────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS apple_subscription_bindings (
  original_transaction_id  TEXT        PRIMARY KEY,
  user_id                  INTEGER     NOT NULL REFERENCES users (id),
  bound_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Backfill from existing webhook_events: earliest INITIAL_PURCHASE per
-- transaction ID wins (lowest processed_at).
INSERT INTO apple_subscription_bindings (original_transaction_id, user_id, bound_at)
SELECT DISTINCT ON (raw_payload->'event'->>'original_transaction_id')
  raw_payload->'event'->>'original_transaction_id',
  user_id,
  processed_at
FROM webhook_events
WHERE event_type = 'INITIAL_PURCHASE'
  AND user_id IS NOT NULL
  AND raw_payload->'event'->>'original_transaction_id' IS NOT NULL
ORDER BY raw_payload->'event'->>'original_transaction_id', processed_at ASC
ON CONFLICT DO NOTHING;


-- ── DOWN ──────────────────────────────────────────────────────────────────────

-- DROP TABLE IF EXISTS apple_subscription_bindings;
