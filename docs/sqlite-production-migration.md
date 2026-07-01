# SQLite Production Migration Issue

## Problem

Payload CMS 3 + SQLite in production standalone mode: database tables are not created, causing `no such table` errors.

```
SQLITE_ERROR: no such table: users
SQLITE_ERROR: no such table: posts
```

## Root Cause

`push: true` in the SQLite adapter config **only works in development mode**. In production, Payload explicitly disables it for safety. This is by design — see [Payload docs](https://payloadcms.com/docs/database/sqlite):

> `push` is a development-only tool that leverages Drizzle's `db push`. It only works in development mode. For production, you should use migrations.

## Wrong Approaches (what we tried)

1. **Setting `push: true`** — Ignored in production
2. **Running `npx payload generate:db-schema` in container** — Payload CLI not available in standalone output
3. **Build-time schema push with template database** — Volume mount at runtime overwrites the template
4. **Custom entrypoint script** — Standalone output doesn't include Payload source code or CLI

## Correct Solution

Use Payload's `prodMigrations` option — automatically runs migrations at startup in production.

### Step 1: Generate initial migration

```bash
npx payload migrate:create init --force-accept-warning --skip-empty
```

This creates files in `src/migrations/`:
- `YYYYMMDD_HHMMSS_init.ts` — migration up/down functions
- `YYYYMMDD_HHMMSS_init.json` — migration metadata
- `index.ts` — exports all migrations

### Step 2: Update payload.config.ts

```ts
import { sqliteAdapter } from '@payloadcms/db-sqlite'
import { migrations } from './migrations'

export default buildConfig({
  db: sqliteAdapter({
    client: {
      url: process.env.DATABASE_URI || 'file:./db/database.db',
    },
    prodMigrations: migrations,  // <-- auto-run migrations in production
  }),
})
```

### Step 3: Redeploy

```bash
pnpm docker:build
pnpm docker:push
```

Payload will automatically apply migrations on container startup.

## How It Works

| Environment | Mechanism | Behavior |
|-------------|-----------|----------|
| Development (`pnpm dev`) | `push: true` (default) | Auto-syncs schema on every startup |
| Production (`pnpm start`) | `prodMigrations` | Runs pending migrations on startup |

## Key Points

- `push: true` and `prodMigrations` serve different purposes — do not use both
- Migrations are **tracked** — Payload records which migrations have been applied
- Each migration runs in a **transaction** — if it fails, no changes are made
- Future schema changes: run `npx payload migrate:create` to generate new migration, then deploy

## References

- [Payload SQLite Docs](https://payloadcms.com/docs/database/sqlite)
- [Payload Migrations Docs](https://payloadcms.com/docs/database/migrations)
