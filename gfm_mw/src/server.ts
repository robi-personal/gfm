import { createApp } from "./app";
import { env } from "./config/env";
import { logger } from "./infrastructure/logger";
import { runMigrations } from "./infrastructure/db/migrate";
import { pool } from "./infrastructure/db/postgres";

async function start() {
  await runMigrations();

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
