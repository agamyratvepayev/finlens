import { config } from '../config.js';
import { SUPPORTED, DEFAULT_LANG, loadLocale, isSupported, pickLang } from '../i18n/index.js';

const LANG_COOKIE = 'lang';

/**
 * Builds the context every view needs: the active locale dictionary, the
 * language and the per-language URLs for the switcher (same page, other lang).
 */
export function viewContext(request, lang, subPath = '', extra = {}) {
  const switchPaths = {};
  for (const l of SUPPORTED) switchPaths[l] = `/${l}${subPath}`;
  return {
    t: loadLocale(lang),
    lang,
    supported: SUPPORTED,
    switchPaths,
    baseUrl: config.baseUrl,
    canonical: `${config.baseUrl}/${lang}${subPath}`,
    ...extra,
  };
}

export default async function pageRoutes(fastify) {
  // Bare root → negotiate a language and redirect.
  fastify.get('/', async (request, reply) => {
    const cookieLang = request.cookies?.[LANG_COOKIE];
    const lang = pickLang({ cookieLang, acceptLanguage: request.headers['accept-language'] });
    reply.redirect(`/${lang}`, 302);
  });

  // Landing page.
  fastify.get('/:lang', async (request, reply) => {
    const { lang } = request.params;
    if (!isSupported(lang)) return notFound(request, reply);
    setLangCookie(reply, lang);

    const csrfToken = reply.generateCsrf();
    const sent = request.query?.sent === '1';

    return reply.view('pages/landing.ejs', viewContext(request, lang, '', {
      page: 'landing',
      csrfToken,
      sent,
      errors: {},
      values: { name: '', email: '', message: '' },
      formError: null,
    }));
  });

  // Privacy policy.
  fastify.get('/:lang/privacy', async (request, reply) => {
    const { lang } = request.params;
    if (!isSupported(lang)) return notFound(request, reply);
    setLangCookie(reply, lang);
    return reply.view('pages/privacy.ejs', viewContext(request, lang, '/privacy', {
      page: 'privacy',
    }));
  });
}

export function setLangCookie(reply, lang) {
  reply.setCookie(LANG_COOKIE, lang, {
    path: '/',
    httpOnly: false,
    sameSite: 'lax',
    secure: config.isProd,
    maxAge: 60 * 60 * 24 * 365,
  });
}

export function notFound(request, reply) {
  const lang = isSupported(request.params?.lang) ? request.params.lang : DEFAULT_LANG;
  return reply.code(404).view('pages/404.ejs', viewContext(request, lang, '', { page: '404' }));
}
