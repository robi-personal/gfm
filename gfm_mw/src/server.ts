import { createApp } from "./app";
import { env } from "./config/env";
import { logger } from "./infrastructure/logger";

const app = createApp();

const server = app.listen(env.PORT, () => {
  logger.info({ port: env.PORT, env: env.NODE_ENV }, "server_started");
});

// Graceful shutdown — lets Docker stop the container cleanly.
const shutdown = (signal: string) => {
  logger.info({ signal }, "shutdown_initiated");
  server.close(() => {
    logger.info("server_closed");
    process.exit(0);
  });
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
