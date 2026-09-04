import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { config } from '../config.js';

/**
 * Tiny file-based i18n. Each supported language has a JSON dictionary in
 * ./locales; templates read strings as `t.section.key`.
 *
 * Language is carried in the URL prefix (/ru, /tk, /en). `ru` is the default.
 */

export const SUPPORTED = ['ru', 'tk', 'en'];
export const DEFAULT_LANG = 'ru';

const localesDir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'locales');

function readLocale(lang) {
  const raw = readFileSync(path.join(localesDir, `${lang}.json`), 'utf8');
  return JSON.parse(raw);
}

// In production the dictionaries are loaded once and cached; in development we
// re-read on every request so copy edits show up on refresh.
const cache = new Map();

export function loadLocale(lang) {
  const key = SUPPORTED.includes(lang) ? lang : DEFAULT_LANG;
  if (config.isProd) {
    if (!cache.has(key)) cache.set(key, readLocale(key));
    return cache.get(key);
  }
  return readLocale(key);
}

export function isSupported(lang) {
  return SUPPORTED.includes(lang);
}

/**
 * Best-effort language negotiation for the bare `/` redirect:
 * explicit cookie → Accept-Language header → default.
 */
export function pickLang({ cookieLang, acceptLanguage }) {
  if (isSupported(cookieLang)) return cookieLang;
  if (acceptLanguage) {
    const tags = acceptLanguage
      .split(',')
      .map((part) => part.split(';')[0].trim().slice(0, 2).toLowerCase());
    for (const tag of tags) {
      if (isSupported(tag)) return tag;
    }
  }
  return DEFAULT_LANG;
}
