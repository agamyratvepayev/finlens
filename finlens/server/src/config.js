import 'dotenv/config';

/**
 * Reads and validates configuration from the environment exactly once at boot.
 * Everything the app needs comes through this object — no `process.env` reads
 * scattered across the codebase.
 */

function required(name) {
  const v = process.env[name];
  if (v === undefined || v === '') {
    throw new Error(`Missing required env var: ${name}`);
  }
  return v;
}

function optional(name, fallback) {
  const v = process.env[name];
  return v === undefined || v === '' ? fallback : v;
}

function intEnv(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const n = Number.parseInt(raw, 10);
  if (Number.isNaN(n)) throw new Error(`Env var ${name} must be an integer`);
  return n;
}

const nodeEnv = optional('NODE_ENV', 'development');
const isProd = nodeEnv === 'production';

// Postgres: prefer DATABASE_URL, otherwise assemble from PG* parts.
function databaseUrl() {
  const url = optional('DATABASE_URL', '');
  if (url) return url;
  const host = optional('PGHOST', 'localhost');
  const port = optional('PGPORT', '5432');
  const user = optional('PGUSER', 'finlens');
  const password = optional('PGPASSWORD', 'finlens');
  const db = optional('PGDATABASE', 'finlens_landing');
  return `postgres://${user}:${password}@${host}:${port}/${db}`;
}

export const config = {
  nodeEnv,
  isProd,
  host: optional('HOST', '0.0.0.0'),
  port: intEnv('PORT', 3000),
  baseUrl: optional('BASE_URL', `http://localhost:${intEnv('PORT', 3000)}`),
  databaseUrl: databaseUrl(),
  redisUrl: optional('REDIS_URL', 'redis://localhost:6379'),
  cookieSecret: isProd ? required('COOKIE_SECRET') : optional('COOKIE_SECRET', 'dev-insecure-cookie-secret'),
  rateLimit: {
    max: intEnv('RATE_LIMIT_MAX', 5),
    windowMs: intEnv('RATE_LIMIT_WINDOW', 60 * 60 * 1000),
  },
};
