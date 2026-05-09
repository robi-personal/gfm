// Sentry must be initialized before any other imports that might throw.
import * as Sentry from "@sentry/node";
import { env } from "./config/env";

Sentry.init({
  dsn: env.SENTRY_DSN,
  environment: env.NODE_ENV,
  release: process.env["npm_package_version"],
  tracesSampleRate: 0.05,
});

import { createApp } from "./app";
import { logger } from "./infrastructure/logger";
import { runMigrations } from "./infrastructure/db/migrate";
import { pool } from "./infrastructure/db/postgres";
import { configService } from "./config/config-service";

async function start() {
  await runMigrations();
  await configService.load();

  const app = createApp();
  const server = app.listen(env.PORT, () => {
    logger.info({ port: env.PORT, env: env.NODE_ENV }, "server_started");
  });

  // Graceful shutdown — lets Docker stop the container cleanly.
  const shutdown = (signal: string) => {
    logger.info({ signal }, "shutdown_initiated");
    server.close(async () => {
      await pool.end();
      logger.info("server_closed");
      process.exit(0);
    });
  };

  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT",  () => shutdown("SIGINT"));
}

start().catch((err) => {
  console.error("startup_failed", err);
  process.exit(1);
});
