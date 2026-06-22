# Payload Site

Corporate website built with Next.js + Payload CMS + SQLite, featuring CMS content editing and persistent storage, deployed via Docker to Alibaba Cloud ECS.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Next.js 16 (App Router, standalone output) |
| CMS | Payload CMS 3 |
| Database | SQLite (via @payloadcms/db-sqlite) |
| Styling | Tailwind CSS 4 + shadcn/ui (base-ui) |
| Rich Text | Lexical Editor |
| Deployment | Docker + nginx + Alibaba Cloud ECS |

## Architecture

```
                    ┌──────────────────────────────────────────┐
                    │           Alibaba Cloud ECS              │
                    │                                          │
Internet ──────►   │  ┌─────────┐  :80/:443                   │
                    │  │  nginx  │ ────────►                   │
                    │  └─────────┘                             │
                    │       │                                  │
                    │       ▼                                  │
                    │  ┌─────────┐  :3000    ┌──────────┐     │
                    │  │  Next.js│ + Payload │  backup   │     │
                    │  │  + CMS  │           │ (cron 2am)│     │
                    │  └─────────┘           └─────┬────┘     │
                    │       │                      │           │
                    │  ┌────┴────┐            ┌─────▼────┐     │
                    │  │ SQLite  │ (volume)   │   OSS    │     │
                    │  │ + Media │ (volume)   │  (daily) │     │
                    │  └─────────┘            └──────────┘     │
                    └──────────────────────────────────────────┘
```

**Two Docker volumes ensure data persistence:**
- `sqlite-data` → `/app/data` — SQLite database files (CMS content, users, pages, etc.)
- `media-data` → `/app/media` — uploaded image assets

Data in volumes survives container rebuilds and restarts. `docker-compose down` preserves volumes; only `docker-compose down -v` deletes them.

## Project Structure

```
├── src/
│   ├── app/
│   │   ├── (frontend)/          # Public pages (has its own layout)
│   │   │   ├── layout.tsx       # <html>/<body> tags, fonts, global styles
│   │   │   ├── page.tsx         # Homepage (user list)
│   │   │   └── globals.css
│   │   ├── (payload)/           # Payload CMS admin (auto-generated)
│   │   │   └── admin/
│   │   ├── api/
│   │   │   ├── [...slug]/       # Payload REST API (auto-generated)
│   │   │   └── health/          # Health check endpoint
│   │   └── layout.tsx           # Root layout (returns children only)
│   ├── components/ui/           # shadcn/ui components
│   ├── lib/utils.ts
│   └── payload.config.ts        # Payload CMS config (collections, adapter, etc.)
├── scripts/
│   ├── backup.sh                # Automated backup to Alibaba Cloud OSS
│   └── restore.sh               # Data recovery script (local + OSS)
├── docker-entrypoint.sh         # Docker entrypoint (auto-creates tables)
├── init-db.sql                  # SQLite table schema (used by entrypoint)
├── nginx.conf                   # nginx reverse proxy config
├── Dockerfile                   # Multi-stage build (deps → builder → runner)
├── docker-compose.yml           # web + nginx + backup orchestration
└── .env.docker.example          # Deployment env template
```

### Route Groups (critical)

- `(frontend)/` — Public pages with its own `layout.tsx` (contains `<html>` `<body>` tags)
- `(payload)/admin/` — Payload admin panel with auto-generated layout using `RootLayout`
- Root `layout.tsx` — Returns `<>{children}</>` only, avoids nested HTML conflicts

## CMS Data Model

| Collection | Description | Fields |
|------------|-------------|--------|
| `users` | Users (with auth) | name, gender, avatar, email + password |
| `pages` | Page content | title, slug, content(richText), status |
| `media` | Uploaded assets | alt, + auto-managed file metadata |

- `users` and `pages` require login
- `media` is publicly readable, requires login for upload/edit

## Local Development

### Requirements

- Node.js 22+
- pnpm 9+

### Getting Started

```bash
pnpm install
pnpm dev
```

- Public site: http://localhost:3000
- CMS admin: http://localhost:3000/admin

First visit to admin will auto-create the SQLite database and tables.

## Docker Local Testing

```bash
pnpm docker:dev          # Next.js only (no nginx)
pnpm docker:up           # Full stack (Next.js + nginx)
pnpm docker:logs         # View logs
pnpm docker:down         # Stop
```

On first start, `docker-entrypoint.sh` detects an empty database and runs `init-db.sql` to create tables.

## Deploy to Alibaba Cloud ECS

### 1. Prepare ECS

```bash
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker
apt install docker-compose-plugin
```

### 2. Upload Code

```bash
git clone <your-repo-url> /opt/payload-site
cd /opt/payload-site
```

### 3. Configure Environment

```bash
cp .env.docker.example .env
```

Edit `.env` with real values:

```bash
# === Application ===
PAYLOAD_SECRET=<random 32+ char string>
NEXT_PUBLIC_SITE_URL=https://your-domain.com

# === Alibaba Cloud OSS Backup ===
OSS_ENDPOINT=oss-cn-hangzhou-internal.aliyuncs.com
OSS_BUCKET=your-backup-bucket
OSS_ACCESS_KEY_ID=your-access-key-id
OSS_ACCESS_KEY_SECRET=your-access-key-secret
BACKUP_PREFIX=payload-site
```

> ⚠️ `PAYLOAD_SECRET` is the Payload signing key. Never change it after initial setup — existing sessions will be invalidated.
> ⚠️ OSS setup requires creating a bucket and AccessKey in the Alibaba Cloud console. Use a RAM sub-account with OSS read/write permissions only.

### 4. Configure SSL (optional, recommended)

```bash
mkdir -p certs
# Place certificate files in certs/
# certs/fullchain.pem   — certificate chain
# certs/privkey.pem     — private key
```

Edit `nginx.conf` to uncomment the SSL section and update `server_name`.

### 5. Start Services

```bash
docker compose up -d --build
```

### 6. Verify

```bash
# All 3 containers should be running
docker compose ps

# Health check (via nginx on port 80)
curl http://localhost/api/health
# Expected: {"status":"ok"}

# Confirm database initialization
docker compose logs web | grep "Database initialized"

# Check backup logs
docker compose logs backup
```

Visit `http://your-domain.com/admin` to create the first admin user.

### 7. Verify Backup

```bash
# Trigger a manual backup (validates OSS config)
docker compose exec backup sh /app/backup.sh

# Expected: "Upload successful."
# Verify file in OSS bucket: payload-site/backup-YYYYMMDD-HHMMSS.tar.gz
```

## Backup

### Automated Backup

The `backup` container runs daily at 2:00 AM via cron:

```
sqlite3 .backup  ──►  database.db  (safe hot-copy of running DB)
tar -czf         ──►  media.tar.gz (compressed uploaded images)
tar -czf         ──►  backup-YYYYMMDD-HHMMSS.tar.gz (archive)
curl PUT         ──►  Alibaba Cloud OSS (HMAC-SHA1 signed upload)
```

- Uses `sqlite3 .backup` instead of `cp` to avoid corruption during runtime copies
- Auto-cleans backups older than 7 days from OSS
- Local copies are not retained; OSS is the sole backup store

### Backup File Contents

```
backup-YYYYMMDD-HHMMSS.tar.gz
├── database.db      # Full SQLite database copy
└── media.tar.gz     # All uploaded image assets
```

### Manual Backup

```bash
docker compose exec backup sh /app/backup.sh
```

## Data Recovery

Uses `scripts/restore.sh` or corresponding pnpm commands. Supports local backups and OSS remote recovery.

### Quick Commands

```bash
pnpm backup:list            # List local backups
pnpm db:restore <file>      # Restore database
pnpm backup:media <file>    # Restore media files
pnpm backup:full <file>     # Full restore (database + media)
pnpm backup:oss latest      # Download and restore latest from OSS
pnpm backup:oss:list        # List backups on OSS
```

### Scenario 1: Restore to a Point in Time

```bash
# One command to restore the latest backup from OSS
pnpm backup:oss latest

# Or manually:
pnpm backup:oss:list
pnpm backup:oss backup-20260622-020000.tar.gz
```

### Scenario 2: New ECS Instance, Full Recovery

```bash
# 1. Install Docker on new ECS (see deploy step 1)

# 2. Clone code + configure env
git clone <your-repo-url> /opt/payload-site
cd /opt/payload-site
cp .env.docker.example .env
# Edit .env with all config (including OSS)

# 3. Start web container
docker compose up -d --build web

# 4. Restore from OSS
pnpm backup:oss latest

# 5. Start all services
docker compose up -d
```

### Scenario 3: Database Corruption, Restore DB Only

```bash
# From local backup
pnpm backup:list
pnpm db:restore ./backups/database-20260622.db

# From OSS
pnpm backup:oss latest
```

### Scenario 4: Restore Media Files Only

```bash
pnpm backup:media ./backups/media-backup.tar.gz
# Current media is auto-backed up before restore
```

## Quick Reference

### Development & Deployment

| Command | Description |
|---------|-------------|
| `pnpm dev` | Local dev server |
| `pnpm docker:dev` | Docker start (Next.js only) |
| `pnpm docker:up` | Docker start (full stack) |
| `pnpm docker:down` | Docker stop (preserves data) |
| `pnpm docker:logs` | View container logs |
| `pnpm docker:restart` | Restart containers |
| `docker compose down -v` | Stop and **delete** all data |

### Backup & Recovery

| Command | Description |
|---------|-------------|
| `pnpm db:backup` | Backup database to `./backups/` |
| `pnpm backup:list` | List all local backup files |
| `pnpm db:restore <file>` | Restore database |
| `pnpm backup:media <file>` | Restore media files |
| `pnpm backup:full <file>` | Full restore (database + media) |
| `pnpm backup:oss latest` | Restore latest backup from OSS |
| `pnpm backup:oss:list` | List backups on OSS |
| `docker compose exec backup sh /app/backup.sh` | Trigger manual OSS backup |

## Data Persistence

```
Docker Volume (sqlite-data)  ──►  /app/data/database.db
Docker Volume (media-data)   ──►  /app/media/*
```

| Operation | Data Preserved? |
|-----------|----------------|
| `docker compose restart` | ✅ Yes |
| `docker compose down` | ✅ Yes |
| `docker compose down -v` | ❌ Deleted |
| Image rebuild | ✅ Yes (volumes are independent) |
| ECS instance restart | ✅ Yes (volumes on ECS cloud disk) |
| ECS instance termination | ❌ Lost (recover from OSS) |

> ⚠️ Docker volumes on Alibaba Cloud ECS are stored on the system disk by default. System disk termination = data loss. Daily OSS backups provide protection, but periodically verify that backups are uploading successfully.

---

**Last Updated:** 2026-06-22
