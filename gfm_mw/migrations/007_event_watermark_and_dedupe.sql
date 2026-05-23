-- ============================================================
-- Migration 007 — Out-of-order protection + credit idempotency
--   1. users.last_event_at watermark — guards all premium-state UPDATEs
--      against late RC webhook delivery (see purchase-flow.md §6.3).
--   2. UNIQUE partial index on quota_transactions(user_id, source,
--      product_id, ref_id) WHERE ref_id IS NOT NULL — defense in depth
--      for creditQuota, beyond the outer webhook_events.event_id UNIQUE.
-- ============================================================

-- ── UP ────────────────────────────────────────────────────────────────────────

-- 1. Event-timestamp watermark. NULL means "no RC event has ever advanced
--    this row" — first event wins unconditionally.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_event_at TIMESTAMPTZ;

-- 2. Credit-operation idempotency. Catches duplicate creditQuota calls with
--    the same (user, source, product, ref_id) tuple — covers the cases the
--    webhook_events PK does NOT cover (sync-heal credits, future admin tools).
CREATE UNIQUE INDEX IF NOT EXISTS quota_transactions_dedupe_idx
  ON quota_transactions (user_id, source, product_id, ref_id)
  WHERE ref_id IS NOT NULL;


-- ── DOWN ──────────────────────────────────────────────────────────────────────

-- DROP INDEX IF EXISTS quota_transactions_dedupe_idx;
-- ALTER TABLE users DROP COLUMN IF EXISTS last_event_at;
