import { buildApp } from './app.js';
import { config } from './config.js';
import { closePool } from './db/pool.js';
import { closeRedis } from './redis/client.js';

/**
 * Process entry point: build the app, start listening, and shut down cleanly.
 */
const app = await buildApp();

try {
  await app.listen({ host: config.host, port: config.port });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}

async function shutdown(signal) {
  app.log.info(`${signal} received — shutting down`);
  try {
    await app.close();
    await closePool();
    await closeRedis();
  } catch (err) {
    app.log.error({ err }, 'error during shutdown');
  } finally {
    process.exit(0);
  }
}

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => shutdown(signal));
}
