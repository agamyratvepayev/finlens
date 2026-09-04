import fp from 'fastify-plugin';
import fastifyRateLimit from '@fastify/rate-limit';
import { redis } from '../redis/client.js';
import { config } from '../config.js';
import { loadLocale, isSupported, DEFAULT_LANG } from '../i18n/index.js';

/**
 * Rate limiting backed by Redis. Registered with `global: false` so only routes
 * that opt in (the contact POST) are limited — page views are never throttled.
 * On limit the response is a localized 429 (JSON), which is fine for the rare
 * abusive client the limit is meant to stop.
 */
async function ratelimit(fastify) {
  await fastify.register(fastifyRateLimit, {
    global: false,
    redis,
    max: config.rateLimit.max,
    timeWindow: config.rateLimit.windowMs,
    // Namespaced so these keys don't collide with app anti-spam keys.
    nameSpace: 'finlens-rl:',
    errorResponseBuilder: (request, context) => {
      const lang = isSupported(request.params?.lang) ? request.params.lang : DEFAULT_LANG;
      const t = loadLocale(lang);
      return {
        statusCode: 429,
        error: 'Too Many Requests',
        message: t.contact.errRate,
        retryAfter: context.ttl,
      };
    },
  });
}

export default fp(ratelimit, { name: 'ratelimit' });
