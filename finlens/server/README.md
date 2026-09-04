# FinLens — Landing Site

Marketing landing page for **FinLens**, a personal-finance app for Turkmenistan.
Trilingual (**ru / tk / en**) with a contact form. Built with Fastify + EJS,
Postgres for stored messages, Redis for rate-limiting.

## Requirements

- Node.js ≥ 20
- Postgres + Redis (use the bundled `docker-compose.yml` for local dev)

## Setup

```bash
cd server
npm install
cp .env.example .env          # then edit values
docker compose up -d          # starts postgres + redis (optional, for local dev)
npm run migrate               # creates the database tables
npm run dev                   # http://localhost:3000  → redirects to /ru
```

`npm start` runs the production entry point (no file watching).

## Routes

| Route              | What it does                                            |
| ------------------ | ------------------------------------------------------- |
| `GET /`            | Redirects to a language (`cookie` → `Accept-Language` → `ru`) |
| `GET /:lang`       | Landing page (`ru` \| `tk` \| `en`)                     |
| `GET /:lang/privacy` | Privacy policy                                        |
| `POST /:lang/contact` | Contact form submit → stores a row, redirects `?sent=1` |
| `GET /healthz`     | Health check (pings Postgres + Redis)                   |

## Configuration

All config comes from environment variables — see `.env.example`. In production,
`COOKIE_SECRET` is required. The contact form is rate-limited per IP
(`RATE_LIMIT_MAX` submissions per `RATE_LIMIT_WINDOW` ms), backed by Redis.

## Internationalisation

Copy lives in `src/i18n/locales/{ru,tk,en}.json`. Add a key to all three files
and reference it in the EJS templates via `t.section.key`. Default language is
`ru`; the language switcher lives in the header.

## Data model

`src/db/migrations/001_init.sql`:

- `contact_messages` — form submissions (`name`, `email`, `message`, `lang`, `ip`, …)
- `users` — reserved for a future user-registration feature (not used yet)
- `_migrations` — tracks which migration files have been applied

Migrations are plain `.sql` files applied in filename order, each in a
transaction, idempotently. Add new ones as `002_*.sql`, `003_*.sql`, …

## Out of scope (for now)

User registration/login, email/Telegram notifications, and an admin inbox are
intentionally deferred. The DB schema already reserves a `users` table so
registration can be added without a rewrite.
