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

### 1. Check Database Changes

If you modified collections or fields in `payload.config.ts`:

```bash
pnpm payload:migrate:create
git add src/migrations/
git commit -m 'chore: add migration for ...'
```

If no schema changes, skip this step.

### 2. Build & Push Image

**Option A: Local build**

```bash
pnpm docker:build                    # tag: commitHash-timestamp
pnpm docker:push                     # push to ACR

# Or specify a version tag
TAG=v1.2.5 pnpm docker:build
TAG=v1.2.5 pnpm docker:push
```

First time, login to ACR locally:

```bash
docker login <ACR_REGISTRY> -u <username>
```

**Option B: CI build (GitHub Actions)**

```bash
git tag v1.2.5
git push origin v1.2.5
```

CI auto-builds and pushes to ACR. Reuses `docker/build.sh` and `docker/push.sh`.

### 3. Deploy to ECS

Requires SSH access to ECS from your local machine.

```bash
bash scripts/deploy-ecs.sh <ECS_IP> <image_tag>
```

Handles: ACR login → upload `.env.local` → create directory → pull image → create container.

### 4. BaoTa nginx & SSL (One-time)

**Install via BaoTa**

- Docker Manager
- Nginx

**Configure ACR**

BaoTa → Docker → Image Registry → Add Registry

**Configure reverse proxy**

1. BaoTa → Websites → Add Site → Reverse Proxy → `http://127.0.0.1:3000`
2. BaoTa → Websites → Site Settings → Config → Add to `location /` block:
   ```nginx
   proxy_set_header Origin "https://$host";
   ```
3. BaoTa → Websites → SSL → Issue Let's Encrypt certificate

## Operations

### Database Backup

BaoTa → Scheduled Tasks → Backup Directory → select `/opt/notes/db/`.

Images are stored on OSS, no backup needed.

### Update Deploy

```bash
bash scripts/deploy-ecs.sh <ECS_IP> <new_image_tag>
```

Or push a new git tag for CI auto-build, then run the deploy script.

### Health Check

```bash
curl http://localhost:3000/api/health
# Returns: { "status": "ok" }
```

### Troubleshooting

```bash
docker logs my-notes
docker ps -a
docker exec -it my-notes sh
docker restart my-notes
```

## Pitfalls

- [SQLite Production Migration](docs/sqlite-production-migration.md) — `push: true` doesn't work in production, use `prodMigrations` instead
- [General Pitfalls](docs/pitfalls.md) — other real-world issues encountered during development and deployment

## License

MIT
