-- ============================================================
-- Migration 009 — Account deletion requests
--   Tracks scheduled account deletions. A row means the user
--   has requested deletion. Any subsequent sign-in removes the
--   row silently (cancels deletion). A nightly cron purges all
--   data for rows older than 30 days.
-- ============================================================

-- ── UP ────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS account_deletion_requests (
  id                    SERIAL      PRIMARY KEY,
  user_id               INTEGER     NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
  deletion_requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ── DOWN ──────────────────────────────────────────────────────────────────────

-- DROP TABLE IF EXISTS account_deletion_requests;
