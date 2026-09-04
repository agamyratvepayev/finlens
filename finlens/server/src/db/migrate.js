import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { pool, closePool } from './pool.js';

/**
 * Minimal migration runner: applies every `*.sql` file in ./migrations in
 * filename order, each inside a transaction, recording applied files in a
 * `_migrations` table so re-runs are a no-op.
 *
 * Run with: npm run migrate
 */

const migrationsDir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'migrations');

async function ensureMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      name       TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

async function appliedSet(client) {
  const { rows } = await client.query('SELECT name FROM _migrations');
  return new Set(rows.map((r) => r.name));
}

async function run() {
  const files = (await readdir(migrationsDir))
    .filter((f) => f.endsWith('.sql'))
    .sort();

  const client = await pool.connect();
  try {
    await ensureMigrationsTable(client);
    const done = await appliedSet(client);

    let appliedCount = 0;
    for (const file of files) {
      if (done.has(file)) {
        console.log(`= skip ${file} (already applied)`);
        continue;
      }
      const sql = await readFile(path.join(migrationsDir, file), 'utf8');
      console.log(`→ applying ${file} ...`);
      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query('INSERT INTO _migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
        appliedCount += 1;
        console.log(`✓ applied ${file}`);
      } catch (err) {
        await client.query('ROLLBACK');
        throw new Error(`Migration ${file} failed: ${err.message}`);
      }
    }

    console.log(appliedCount === 0 ? 'Nothing to migrate.' : `Done — ${appliedCount} migration(s) applied.`);
  } finally {
    client.release();
    await closePool();
  }
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
