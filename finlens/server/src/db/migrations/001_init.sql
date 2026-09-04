-- 001_init — landing site schema.

-- Contact / feedback form submissions. This is the only table the app writes
-- to today.
CREATE TABLE IF NOT EXISTS contact_messages (
    id          BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT        NOT NULL,
    email       TEXT        NOT NULL,
    message     TEXT        NOT NULL,
    lang        TEXT        NOT NULL DEFAULT 'ru',
    ip          TEXT,
    user_agent  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS contact_messages_created_at_idx
    ON contact_messages (created_at DESC);

-- Reserved for a future user-registration feature. Created now so registration
-- can be added later without a schema rewrite; nothing writes to it yet.
CREATE TABLE IF NOT EXISTS users (
    id          BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT        NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
