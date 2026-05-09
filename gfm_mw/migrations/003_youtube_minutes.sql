-- ============================================================
-- UP
-- ============================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS youtube_minutes_used     INTEGER     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS youtube_minutes_reset_at TIMESTAMPTZ NULL;


-- ============================================================
-- DOWN
-- ============================================================
-- ALTER TABLE users DROP COLUMN IF EXISTS youtube_minutes_used;
-- ALTER TABLE users DROP COLUMN IF EXISTS youtube_minutes_reset_at;
