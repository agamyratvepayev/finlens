import pg from 'pg';
import { config } from '../config.js';

const { Pool } = pg;

/**
 * Single shared connection pool. Import `pool` anywhere that needs the DB;
 * call `closePool()` on shutdown.
 */
export const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 10_000,
});

pool.on('error', (err) => {
  // A pooled client dropped while idle — log and let the pool recover.
  console.error('[pg] idle client error:', err.message);
});

export async function closePool() {
  await pool.end();
}
