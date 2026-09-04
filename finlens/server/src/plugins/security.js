import fp from 'fastify-plugin';
import fastifyCookie from '@fastify/cookie';
import fastifyHelmet from '@fastify/helmet';
import fastifyCsrf from '@fastify/csrf-protection';
import { config } from '../config.js';

/**
 * Cookie signing, security headers (helmet + CSP) and CSRF protection.
 * Registered as a plugin so `fastify.csrfProtection` is available to routes.
 *
 * CSP allows only same-origin assets. Styles/scripts are self-hosted, so no
 * 'unsafe-inline' is needed for them; a couple of tiny inline hooks live in
 * external files under /public instead.
 */
async function security(fastify) {
  await fastify.register(fastifyCookie, {
    secret: config.cookieSecret,
  });

  await fastify.register(fastifyHelmet, {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        baseUri: ["'self'"],
        scriptSrc: ["'self'"],
        // Inline style *attributes* colour the CSS mockups; scripts stay strict.
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:'],
        fontSrc: ["'self'", 'data:'],
        connectSrc: ["'self'"],
        formAction: ["'self'"],
        frameAncestors: ["'none'"],
        objectSrc: ["'none'"],
      },
    },
    // The site is HTTP in local dev; enable HSTS only in production.
    hsts: config.isProd,
    crossOriginEmbedderPolicy: false,
  });

  await fastify.register(fastifyCsrf, {
    cookieOpts: {
      signed: true,
      httpOnly: true,
      sameSite: 'lax',
      secure: config.isProd,
      path: '/',
    },
  });
}

export default fp(security, { name: 'security' });
