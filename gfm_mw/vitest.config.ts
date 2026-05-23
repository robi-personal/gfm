import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Single-thread: tests share a Postgres test DB and each test wraps
    // in BEGIN/ROLLBACK. Parallel runs would interleave transactions on
    // the same connections — single-thread keeps assertions deterministic.
    pool: "forks",
    poolOptions: {
      forks: { singleFork: true },
    },
    setupFiles: ["./tests/setup.ts"],
    testTimeout: 30_000,
    hookTimeout: 60_000,
    include: ["tests/**/*.test.ts"],
    // env.ts validates a long list of env vars at module load. The repository
    // tests don't touch most of these, but the schema rejects boot without
    // them. Provide fake-but-valid values up front so any module import chain
    // (logger → env, postgres → env, etc.) loads cleanly.
    env: {
      NODE_ENV:                 "development",
      DATABASE_URL:             "postgres://gfm:gfm@localhost:5432/gfm_test",
      REDIS_URL:                "redis://localhost:6379",
      GOOGLE_CLIENT_ID:         "test-client-id",
      RC_WEBHOOK_SECRET:        "test-rc-webhook-secret",
      GEMINI_API_KEY:           "test-gemini-key",
      HEALTH_TOKEN:             "x".repeat(32),
      ADMIN_TOKEN:              "x".repeat(32),
      ADMIN_EMAIL:              "test@example.com",
      ADMIN_PASSWORD:           "test-password",
    },
  },
});
