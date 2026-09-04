import crypto from 'node:crypto';
import { pool } from '../db/pool.js';
import { redis } from '../redis/client.js';
import { config } from '../config.js';
import { isSupported } from '../i18n/index.js';
import { validateContact, isSpam } from '../lib/validate.js';
import { viewContext, notFound } from './pages.js';

// Reject a byte-identical resend from the same person for a short window.
const DEDUPE_TTL_SECONDS = 10 * 60;

export default async function contactRoutes(fastify) {
  fastify.post(
    '/:lang/contact',
    {
      preHandler: fastify.csrfProtection,
      config: {
        rateLimit: {
          max: config.rateLimit.max,
          timeWindow: config.rateLimit.windowMs,
        },
      },
    },
    async (request, reply) => {
      const { lang } = request.params;
      if (!isSupported(lang)) return notFound(request, reply);

      // Honeypot filled → silently accept without storing anything.
      if (isSpam(request.body)) {
        return reply.redirect(`/${lang}?sent=1`, 303);
      }

      const { values, errors, ok } = validateContact(request.body);

      if (!ok) {
        return reply.code(422).view('pages/landing.ejs', viewContext(request, lang, '', {
          page: 'landing',
          csrfToken: reply.generateCsrf(),
          sent: false,
          errors,
          values,
          formError: 'errorGeneric',
        }));
      }

      // Anti-duplicate: hash of email+message; if seen recently, treat as sent.
      const dupeKey = `finlens-dedupe:${crypto
        .createHash('sha256')
        .update(`${values.email}|${values.message}`)
        .digest('hex')}`;
      const fresh = await redis.set(dupeKey, '1', 'EX', DEDUPE_TTL_SECONDS, 'NX');
      if (fresh === null) {
        return reply.redirect(`/${lang}?sent=1`, 303);
      }

      await pool.query(
        `INSERT INTO contact_messages (name, email, message, lang, ip, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          values.name,
          values.email,
          values.message,
          lang,
          request.ip,
          request.headers['user-agent'] ?? null,
        ],
      );

      return reply.redirect(`/${lang}?sent=1`, 303);
    },
  );
}
