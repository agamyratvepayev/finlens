import { pool } from '../db/pool.js';
import { redis } from '../redis/client.js';

/**
 * Liveness/readiness probe: confirms Postgres and Redis are both reachable.
 */
export default async function healthRoutes(fastify) {
  fastify.get('/healthz', async (request, reply) => {
    const checks = { postgres: false, redis: false };
    try {
      await pool.query('SELECT 1');
      checks.postgres = true;
    } catch (err) {
      request.log.error({ err }, 'healthz: postgres check failed');
    }
    try {
      const pong = await redis.ping();
      checks.redis = pong === 'PONG';
    } catch (err) {
      request.log.error({ err }, 'healthz: redis check failed');
    }

    const ok = checks.postgres && checks.redis;
    reply.code(ok ? 200 : 503).send({ status: ok ? 'ok' : 'degraded', checks });
  });
}
