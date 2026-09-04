/**
 * Server-side validation for the contact form. Returns `{ values, errors }`
 * where `values` is the trimmed/clamped input to echo back, and `errors` maps
 * field → i18n key (empty object means valid).
 */

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const LIMITS = {
  name: { min: 2, max: 120 },
  email: { min: 5, max: 254 },
  message: { min: 5, max: 4000 },
};

function clean(value, max) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, max);
}

export function validateContact(body = {}) {
  const values = {
    name: clean(body.name, LIMITS.name.max),
    email: clean(body.email, LIMITS.email.max),
    message: clean(body.message, LIMITS.message.max),
  };

  const errors = {};
  if (values.name.length < LIMITS.name.min) errors.name = 'errName';
  if (values.email.length < LIMITS.email.min || !EMAIL_RE.test(values.email)) errors.email = 'errEmail';
  if (values.message.length < LIMITS.message.min) errors.message = 'errMessage';

  return { values, errors, ok: Object.keys(errors).length === 0 };
}

/**
 * Honeypot: a hidden field bots tend to fill. If it has any value, treat the
 * submission as spam.
 */
export function isSpam(body = {}) {
  return typeof body.website === 'string' && body.website.trim() !== '';
}
