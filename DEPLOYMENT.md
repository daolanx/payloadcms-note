# Deployment Guide

## Prerequisites

- Node.js 22+
- pnpm 9+
- Docker & Docker Compose
- Alibaba Cloud ACR (container registry)
- Alibaba Cloud ECS (container host)
- PostgreSQL (cloud or self-hosted)
- Alibaba Cloud OSS (media storage)

## Environment Variables

Copy `.env.example` to `.env.local` and fill in:

```bash
cp .env.example .env.local
```

| Variable | Required | Description |
|----------|----------|-------------|
| `PAYLOAD_SECRET` | Yes | Payload CMS encryption key |
| `DATABASE_URI` | Yes | PostgreSQL connection string |
| `NEXT_PUBLIC_SITE_URL` | Yes | Site URL (e.g. `https://your-domain.com`) |
| `REVALIDATION_SECRET` | Yes | ISR on-demand revalidation secret |
| `OSS_ENDPOINT` | Yes | OSS endpoint |
| `OSS_BUCKET` | Yes | OSS bucket name |
| `OSS_ACCESS_KEY_ID` | Yes | OSS access key ID |
| `OSS_ACCESS_KEY_SECRET` | Yes | OSS access key secret |
| `NEXT_PUBLIC_OSS_ENDPOINT` | Yes | Public OSS endpoint (client-side image loader) |
| `NEXT_PUBLIC_OSS_BUCKET` | Yes | Public OSS bucket name |

---

## 1. Local Development

### Hot Reload (Recommended)

```bash
pnpm install
pnpm dev
# → http://localhost:3000
```

### Docker Testing

```bash
# Build and start (app only, no nginx)
docker compose up -d app --build

# View logs
docker compose logs -f app

# Stop
docker compose down
```

Access at `http://localhost:3000`.

---

## 2. Image Build & Push

### Build Image

```bash
docker build -t crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com/daolanx/payload-notes:<tag> .
```

Example:

```bash
docker build -t crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com/daolanx/payload-notes:v1.0.0 .
```

### Push to ACR

```bash
# Login
docker login --username=daolanx crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com

# Push
docker push crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com/daolanx/payload-notes:v1.0.0
```

---

## 3. ECS Deployment

### First-time Setup

```bash
# SSH into ECS
ssh root@<ecs-host>

# Create deploy directory
mkdir -p /opt/blog && cd /opt/blog

# Copy docker-compose.yml and nginx.conf from repo
# (or clone the repo directly)

# Create .env.local
nano .env.local
# Fill in all environment variables

# Create nginx config
nano nginx.conf
# Uncomment HTTPS block, set your domain

# Create SSL certs directory
mkdir -p certs
# Place cert.pem and key.pem
```

### Pull & Start

```bash
cd /opt/blog

# Login to ACR
docker login --username=daolanx crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com

# Pull latest image
docker compose pull

# Start all services
docker compose up -d

# Verify
docker compose ps
curl -I http://localhost
```

### Update (Subsequent Deploys)

```bash
cd /opt/blog

# Pull new image
docker compose pull

# Restart with new image
docker compose up -d --remove-orphans
```

---

## 4. CI/CD (GitHub Actions)

Push to `main` triggers automatic deployment:

```
Push → Build Image → Push to ACR → SSH to ECS → Pull & Restart
```

### Workflow

1. GitHub Actions builds Docker image
2. Pushes to Alibaba Cloud ACR (tagged with commit SHA + `latest`)
3. SSH into ECS, updates image reference in `docker-compose.yml`
4. Pulls new image and restarts services

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `ACR_PASSWORD` | ACR login password |
| `ECS_HOST` | ECS server IP |
| `ECS_USERNAME` | ECS SSH username |
| `ECS_SSH_KEY` | ECS SSH private key |

### How It Works on ECS

The deploy script on ECS:

```bash
# Updates image tag in docker-compose.yml
sed -i "s|image:.*|image: <acr-image>:<sha>|" docker-compose.yml

# Pull and restart
docker compose pull
docker compose up -d --remove-orphans
```

---

## Architecture

```
                  ┌─────────────┐
  Browser ──────▶ │    nginx    │ :80/:443
                  │  (reverse   │
                  │   proxy)    │
                  └──────┬──────┘
                         │ :3000
                  ┌──────▼──────┐
                  │   Next.js   │
                  │  (standalone)│
                  └──────┬──────┘
                   ┌─────┴─────┐
                   ▼           ▼
             ┌──────────┐ ┌──────────┐
             │ PostgreSQL│ │   OSS    │
             │ (cloud)   │ │ (Alibaba)│
             └──────────┘ └──────────┘
```

### ISR (Incremental Static Regeneration)

- Homepage (`/`) and post pages (`/posts/[slug]`) use ISR with 60s revalidation
- Static pages are cached and served fast
- Auto-regenerate every 60 seconds
- On-demand revalidation: admin create/edit/delete triggers immediate cache invalidation via `/api/revalidate`

---

## SSL Setup

```bash
# Obtain certificates (Let's Encrypt)
sudo certbot certonly --standalone -d your-domain.com

# Copy to project
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ./certs/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ./certs/key.pem
sudo chmod 644 certs/*.pem
```

Then uncomment the HTTPS block in `nginx.conf` and set your domain.

---

## Troubleshooting

### Container won't start

```bash
docker compose logs app
docker stats
```

### nginx 502 Bad Gateway

```bash
docker compose ps          # Check if app is running
docker compose logs app    # Check app errors
docker compose restart app
```

### SSL certificate issues

```bash
ls -la certs/
openssl x509 -in certs/cert.pem -noout -dates
docker compose exec nginx nginx -t
```

### Homepage shows no posts

Posts must have `status: Published` in admin. Draft posts are not shown on the homepage.

---

**Last Updated:** 2026-06-24
