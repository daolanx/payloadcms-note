# My Notes

A self-hosted CMS-powered notes application deployed on Alibaba Cloud ECS, featuring ISR static acceleration, Lexical rich text editing, and OSS image pipeline.

## 1. Why This Design

Next.js + Payload CMS is a highly integrated CMS solution that works great on Vercel and similar platforms. However, in certain regions, network restrictions make Vercel inaccessible or painfully slow. To solve this, the app needs to be self-hosted on ECS — here we use Alibaba Cloud ECS to provide low-latency access for users in that region.
- Payload CMS 3 runs inside Next.js (zero extra servers)
- ISR for performance (static pages + on-demand revalidation)
- OSS for image storage (CDN acceleration, on-the-fly resize)

## 2. Technical Architecture

### Deployment Architecture

```
Browser → nginx (:80/:443) → Next.js (:3000) → PostgreSQL (RDS) + OSS
```

nginx handles SSL termination, reverse proxy, static caching, and security hardening.

### Key Design Decisions

#### ISR + On-demand Revalidation

Traditional CMS pain point: content updates force users to either see stale caches or hit the database on every request.

This project solves it with Next.js ISR:

```
Build time:    generateStaticParams() → pre-render all /posts/[slug] as static HTML
Edit time:     Payload afterChange hook → POST /api/revalidate → revalidatePath()
Runtime:       pages served from cache, auto-regenerate every 60s
```

**Result**: Homepage loads in < 200ms, content updates reflect within 1 second — no cache clearing, no server restart.

#### OSS Image Pipeline

Payload CMS manages media metadata; actual files live on Alibaba Cloud OSS with on-the-fly resize via custom Next.js Image Loader:

```
Payload URL:  /api/media/file/photo.webp
      ↓
OSS URL:      https://bucket.oss-cn-beijing.aliyuncs.com/photo.webp
              ?x-oss-process=image/resize,w_640
```

Images bypass the application server entirely. OSS handles CDN acceleration, format conversion, and bandwidth.

#### Payload CMS 3 Integration

Unlike traditional headless CMS (Strapi, Contentful), Payload CMS 3 runs inside the Next.js process:

- **Zero extra servers** — CMS API and app share one process
- **Lexical rich text editor** — Markdown shortcuts, drag-and-drop image upload
- **Auto type generation** — TypeScript types sync with database schema
- **Plugin architecture** — storage, auth, SEO all pluggable

Access `/admin` after deployment for the admin panel with multi-user support and role-based permissions.

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 + Turbopack |
| CMS | Payload CMS 3 |
| Database | PostgreSQL (Alibaba Cloud RDS) |
| Storage | Alibaba Cloud OSS (S3-compatible) |
| Styling | Tailwind CSS 4 + shadcn/ui |
| Language | TypeScript |

## 3. How to Develop

### Prerequisites

- Node.js 22+
- pnpm
- PostgreSQL (local or RDS)
- Alibaba Cloud OSS bucket

### Quick Start

```bash
# Clone and setup
git clone <repo-url>
cd payload-notes
cp .env.example .env.local
vim .env.local  # Fill in DATABASE_URI, OSS credentials, etc.

# Start dev server
pnpm dev  # http://localhost:3000
```

### Docker Development (Hot Reload)

```bash
docker compose watch
# or
pnpm docker:dev
```

### Available Scripts

| Script | Purpose |
|--------|---------|
| `pnpm dev` | Start dev server with Turbopack |
| `pnpm build` | Production build |
| `pnpm lint` | ESLint |
| `pnpm docker:dev` | Docker dev with hot reload |
| `pnpm docker:build` | Build Docker image |
| `pnpm docker:push` | Push to Alibaba Cloud ACR |
| `pnpm docker:deploy` | Deploy to ECS |
| `pnpm ecs:init` | First-time ECS setup |

## 4. How to Deploy

### First-time ECS Setup

```bash
./scripts/setup-ecs.sh    # or: pnpm ecs:init
```

This script will:
- Create `/opt/notes` directory
- Install Docker (or Podman)
- Install Docker Compose plugin
- Install Portainer (visual container management)
- Upload `compose.yaml` and nginx config

### SSL Certificate

Two options:

```bash
# Option 1: Certbot on ECS
certbot certonly --standalone -d your-domain.com

# Option 2: Local certs, auto-upload via script
pnpm ecs:init
```

After certificates are in place, uncomment the HTTPS block in `nginx.conf`.

### Option A: Manual Deployment

```bash
# Build image locally (linux/amd64 for ECS compatibility)
./scripts/build.sh

# Push to Alibaba Cloud ACR
./scripts/push.sh

# SSH to ECS, pull and restart
./scripts/deploy.sh
```

Or with a specific tag:

```bash
./scripts/build.sh v1.0.0
./scripts/push.sh v1.0.0
./scripts/deploy.sh v1.0.0
```

### Option B: CI/CD (GitHub Actions)

Push to `main` triggers automatic deployment:

```
Build Docker image (linux/amd64)
  → Push to Alibaba Cloud ACR
    → SSH to ECS
      → Pull new image
        → Restart services
```

BuildKit GHA cache enabled for faster subsequent builds.

## 5. Daily Operations

### Container Management (Portainer)

For non-technical team members, Portainer provides a visual container management interface.

**Access**: `http://<ECS_HOST>:9000`

First visit: set admin password → select **Local** environment → manage containers.

**Features**:
- One-click container restart
- View container logs
- Start/stop containers
- Resource usage monitoring
- No command line required

**Security Group**: Make sure port 9000 is open in ECS security group.

### Common Operations

```bash
# Check container status
ssh root@<ECS_HOST>
cd /opt/notes
docker compose ps

# View logs
docker compose logs app

# Restart services
docker compose restart

# Pull new image and restart
docker compose pull
docker compose up -d
```

### Health Check

The app exposes a health check endpoint:

```bash
curl http://localhost:3000/api/health
# Returns: { "status": "ok" }
```

## 6. Pitfalls I Hit

Real-world issues encountered during development and deployment, with solutions.

- Payload CMS Login Fails Silently
- Podman vs Docker Credential Separation
- Mac Build → ECS Deploy Architecture Mismatch
- Next.js 16 Breaking Changes
- Payload CMS CLI ESM Error
- Docker Hub Mirror Acceleration (Domestic)

See [docs/pitfalls.md](docs/pitfalls.md) for detailed descriptions and fixes.

## License

MIT
