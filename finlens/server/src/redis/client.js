import Redis from 'ioredis';
import { config } from '../config.js';

/**
 * Shared Redis connection. Used as the rate-limit backend and for anti-spam
 * (duplicate-submission) keys with a TTL.
 */
export const redis = new Redis(config.redisUrl, {
  maxRetriesPerRequest: 3,
  lazyConnect: false,
});

redis.on('error', (err) => {
  console.error('[redis] error:', err.message);
});

export async function closeRedis() {
  await redis.quit();
}
