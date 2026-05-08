-- Nightly cleanup: purge ai_generations rows whose 60-day retention window has passed.
-- Run via cron (e.g. pg_cron, or a shell cron that calls psql):
--
--   0 3 * * * psql $DATABASE_URL -f /path/to/cleanup_expired_generations.sql
--
-- The index ai_generations_expires_at_idx makes this a fast index scan, not a seq scan.

DELETE FROM ai_generations
WHERE expires_at < NOW();
