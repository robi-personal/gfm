-- ============================================================
-- UP
-- ============================================================

-- ---- users ----

CREATE TABLE users (
  id                  SERIAL          PRIMARY KEY,
  google_sub          TEXT            NOT NULL,
  email               TEXT            NOT NULL,
  created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  ai_free_used        INTEGER         NOT NULL DEFAULT 0,
  ai_premium_used     INTEGER         NOT NULL DEFAULT 0,
  free_month_reset_at TIMESTAMPTZ,
  premium_reset_at    TIMESTAMPTZ,
  is_premium          BOOLEAN         NOT NULL DEFAULT FALSE,
  grace_period_until  TIMESTAMPTZ
);

-- google_sub is the stable identity from the ID token `sub` claim — must be unique.
-- email is denormalized for display only and intentionally NOT unique (users change emails).
CREATE UNIQUE INDEX users_google_sub_idx ON users (google_sub);


-- ---- webhook_events ----

CREATE TABLE webhook_events (
  event_id      TEXT        PRIMARY KEY,   -- RC event.id — PK doubles as idempotency guard
  event_type    TEXT        NOT NULL,
  user_id       INTEGER     REFERENCES users (id),
  raw_payload   JSONB       NOT NULL,
  processed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX webhook_events_user_id_idx ON webhook_events (user_id);


-- ---- ai_generations ----

CREATE TABLE ai_generations (
  id               SERIAL       PRIMARY KEY,
  generation_id    TEXT         NOT NULL,   -- public UUID returned to client
  user_id          INTEGER      NOT NULL REFERENCES users (id),
  idempotency_key  TEXT         NOT NULL,   -- client-supplied UUIDv4
  request_hash     TEXT         NOT NULL,   -- SHA-256 hex of canonicalized request body (§5.2)
  input_type       TEXT         NOT NULL,   -- 'text' | 'pdf' | 'youtube' | 'urls' | 'book'
  input_size       INTEGER,                 -- bytes of decoded input
  input_tokens     INTEGER,
  output_tokens    INTEGER,
  output_json      JSONB,                   -- generated form; NULL for non-success rows
  error_payload    JSONB,                   -- Gemini error or validation failure details
  status           TEXT         NOT NULL,   -- 'processing' | 'success' | 'gemini_error' | 'validation_error'
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  expires_at       TIMESTAMPTZ  NOT NULL DEFAULT (NOW() + INTERVAL '60 days'),

  CONSTRAINT ai_generations_generation_id_key  UNIQUE (generation_id),
  CONSTRAINT ai_generations_user_idempotency_key UNIQUE (user_id, idempotency_key),
  CONSTRAINT ai_generations_status_check CHECK (
    status IN ('processing', 'success', 'gemini_error', 'validation_error')
  )
);

-- Composite index for queries scoped to a user ordered by time (status endpoint, history).
CREATE INDEX ai_generations_user_created_idx ON ai_generations (user_id, created_at DESC);

-- Partial index for the cleanup job — only rows not yet expired need to be scanned by cron.
CREATE INDEX ai_generations_expires_at_idx ON ai_generations (expires_at)
  WHERE expires_at IS NOT NULL;


-- ============================================================
-- DOWN
-- ============================================================
-- DROP TABLE IF EXISTS ai_generations;
-- DROP TABLE IF EXISTS webhook_events;
-- DROP TABLE IF EXISTS users;
