import { fileURLToPath } from 'node:url';
import path from 'node:path';
import Fastify from 'fastify';
import fastifyView from '@fastify/view';
import fastifyStatic from '@fastify/static';
import fastifyFormbody from '@fastify/formbody';
import ejs from 'ejs';

import { config } from './config.js';
import security from './plugins/security.js';
import ratelimit from './plugins/ratelimit.js';
import pageRoutes, { viewContext, notFound } from './routes/pages.js';
import contactRoutes from './routes/contact.js';
import healthRoutes from './routes/health.js';
import { isSupported, DEFAULT_LANG } from './i18n/index.js';

const rootDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');

/**
 * Builds and returns a configured (but not yet listening) Fastify instance.
 */
export async function buildApp() {
  const app = Fastify({
    trustProxy: true,
    logger: config.isProd
      ? true
      : { transport: { target: 'pino-pretty', options: { translateTime: 'HH:MM:ss', ignore: 'pid,hostname' } } },
  });

  // Body parsing for the contact form (application/x-www-form-urlencoded).
  await app.register(fastifyFormbody);

  // Security: cookies, helmet/CSP, CSRF. Must come before routes.
  await app.register(security);

  // Redis-backed rate limiting (opt-in per route).
  await app.register(ratelimit);

  // EJS views with a shared layout.
  await app.register(fastifyView, {
    engine: { ejs },
    root: path.join(rootDir, 'views'),
    viewExt: 'ejs',
    layout: 'layout.ejs',
    defaultContext: { config },
  });

  // Static assets under /public.
  await app.register(fastifyStatic, {
    root: path.join(rootDir, 'public'),
    prefix: '/public/',
  });

  // Routes.
  await app.register(healthRoutes);
  await app.register(pageRoutes);
  await app.register(contactRoutes);

  // 404 → localized page.
  app.setNotFoundHandler((request, reply) => notFound(request, reply));

  // Central error handler. Form-related statuses re-render the landing with a
  // banner; everything else falls back to a generic error page.
  app.setErrorHandler((error, request, reply) => {
    const lang = isSupported(request.params?.lang) ? request.params.lang : DEFAULT_LANG;
    const status = error.statusCode ?? 500;

    if (status === 403) {
      // CSRF failure — re-render the form with a generic error.
      return reply.code(403).view('pages/landing.ejs', viewContext(request, lang, '', {
        page: 'landing',
        csrfToken: reply.generateCsrf(),
        sent: false,
        errors: {},
        values: { name: '', email: '', message: '' },
        formError: 'errorGeneric',
      }));
    }

    request.log.error({ err: error }, 'unhandled error');
    const code = status >= 400 && status < 600 ? status : 500;
    return reply.code(code).view('pages/404.ejs', viewContext(request, lang, '', { page: 'error' }));
  });

  return app;
}
