-- ============================================================
-- Migration 006 — Push notifications for new form responses.
--   • device_tokens — FCM tokens registered per user (multi-device)
--   • form_watches  — routing table: Pub/Sub event (form_id) → user
--   • processed_pubsub_messages — idempotency guard for Pub/Sub deliveries
-- ============================================================

-- ---- device_tokens ----

CREATE TABLE device_tokens (
  id            SERIAL        PRIMARY KEY,
  user_id       INTEGER       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  fcm_token     TEXT          NOT NULL,
  platform      TEXT          NOT NULL CHECK (platform IN ('ios', 'android')),
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  last_seen_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- A given FCM token belongs to at most one user. If the same token appears for a
-- different user (e.g. signed out + signed in as different user on same device),
-- the upsert reassigns it to the new user.
CREATE UNIQUE INDEX device_tokens_token_idx ON device_tokens (fcm_token);
CREATE INDEX device_tokens_user_id_idx ON device_tokens (user_id);


-- ---- form_watches ----

CREATE TABLE form_watches (
  watch_id     TEXT          PRIMARY KEY,   -- Google's watch.id, also our routing key
  form_id      TEXT          NOT NULL,
  user_id      INTEGER       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  form_title   TEXT          NOT NULL DEFAULT '',  -- cached for notification body
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ   NOT NULL
);

-- One active watch per (form, user) pair. If the user re-toggles, the new watch_id
-- replaces the old one via ON CONFLICT.
CREATE UNIQUE INDEX form_watches_form_user_idx ON form_watches (form_id, user_id);
CREATE INDEX form_watches_form_id_idx ON form_watches (form_id);


-- ---- processed_pubsub_messages ----
-- Pub/Sub guarantees at-least-once delivery; this table de-duplicates by message_id.
-- Rows are cheap (TEXT + timestamp); a cleanup job can prune entries older than ~24h.

CREATE TABLE processed_pubsub_messages (
  message_id    TEXT          PRIMARY KEY,
  processed_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);


-- ============================================================
-- DOWN
-- ============================================================
-- DROP TABLE IF EXISTS processed_pubsub_messages;
-- DROP TABLE IF EXISTS form_watches;
-- DROP TABLE IF EXISTS device_tokens;
