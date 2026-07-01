# My Notes

A self-hosted CMS-powered notes application deployed on Alibaba Cloud ECS via BaoTa Panel, featuring ISR static acceleration, Lexical rich text editing, and OSS image pipeline.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 + Turbopack |
| CMS | Payload CMS 3 |
| Database | SQLite |
| Storage | Alibaba Cloud OSS (S3-compatible) |
| Styling | Tailwind CSS 4 + shadcn/ui |
| Language | TypeScript |

## Architecture

```
Browser → nginx → Docker → SQLite + OSS
```

### ISR + On-demand Revalidation

```
Build time:    generateStaticParams() → pre-render /posts/[slug] as static HTML
Edit time:     Payload afterChange hook → POST /api/revalidate → revalidatePath()
Runtime:       pages served from cache, auto-regenerate every 60s
```

### OSS Image Pipeline

Images are stored on Alibaba Cloud OSS with on-the-fly resize. The app server is completely bypassed for image delivery.

## Development

### Prerequisites

- Node.js 22+
- pnpm

### Quick Start

```bash
git clone <repo-url>
cd payload-notes
cp .env.example .env.local
# Edit .env.local with your OSS credentials
pnpm dev  # http://localhost:3000
```

### Scripts

| Script | Purpose |
|--------|---------|
| `pnpm dev` | Start dev server with Turbopack |
| `pnpm build` | Production build |
| `pnpm lint` | ESLint |
| `pnpm payload:gen-importmap` | Regenerate Payload admin import map |
| `pnpm docker:build` | Build Docker image (tag: commitHash-timestamp) |
| `pnpm docker:push` | Push latest local image to ACR |

## Deployment

### 1. ECS Initialization

One-time setup to prepare the server environment.

**Install BaoTa Panel**

ECS console → Instance details → Extensions → Search "BaoTa" → Install

**Install via BaoTa**

- Docker Manager
- Nginx

**Configure ACR**

1. BaoTa → Docker → Image Registry → Add Registry
2. Fill in ACR registry address, username, and password

**Prepare environment variables**

```bash
scp .env.local root@<ECS_IP>:/opt/notes/.env.local
```

Reference `.env.example` for all required variables.

### 2. Deployment

#### Build Image

**Option A: Local build**

```bash
pnpm docker:build                    # tag: commitHash-timestamp
pnpm docker:push                     # push to ACR

# Or specify a version tag
TAG=v1.1.0 pnpm docker:build
TAG=v1.1.0 pnpm docker:push
```

First time, login to ACR locally:

```bash
docker login <ACR_REGISTRY> -u <username>
```

**Option B: CI build (GitHub Actions)**

Push a git tag to trigger automatic build and push:

```bash
git tag v1.1.0
git push origin v1.1.0
```

CI reuses the same `docker/build.sh` and `docker/push.sh` scripts.

#### Deploy to ECS

**First deploy:**

1. Create data directory: `mkdir -p /opt/notes/db`
2. BaoTa → Docker → Image Management → Pull your image
3. Create container:
   - Port: `127.0.0.1:3000:3000`
   - Volume: `/opt/notes/db:/app/db`
   - Env vars: from `.env.local`
   - Restart: Always
4. BaoTa → Websites → Add Site → Reverse Proxy:
   - Name: `notes-app`
   - Target: `http://127.0.0.1:3000`
5. BaoTa → Websites → Site Settings → Config → Add to `location /` block:
   ```nginx
   proxy_set_header Origin "https://$host";
   ```
6. BaoTa → Websites → SSL → Issue Let's Encrypt certificate

**Update deploy:**

1. BaoTa → Docker → Image Management → Pull latest image
2. BaoTa → Docker → Containers → Recreate with same config

## Operations

### Database Backup

SQLite database is stored at `/opt/notes/db/database.db` on ECS:

```bash
# Manual backup
cp /opt/notes/db/database.db /opt/notes/db/backup-$(date +%Y%m%d).db

# Keep last 7 days
find /opt/notes/db -name "backup-*.db" -mtime +7 -delete
```

### Health Check

```bash
curl http://localhost:3000/api/health
# Returns: { "status": "ok" }
```

### Troubleshooting

```bash
docker logs notes-app
docker ps -a
docker exec -it notes-app sh
docker restart notes-app
```

## Pitfalls

See [docs/pitfalls.md](docs/pitfalls.md) for real-world issues encountered during development and deployment.

## License

MIT
