# Deployment Guide

## Prerequisites

- Node.js 22+, pnpm 9+, Docker & Docker Compose
- SSH access to ECS server
- Alibaba Cloud ACR account (container registry)

## Environment Variables

```bash
cp .env.example .env.local
# Fill in all values — both app config and deploy config
```

---

## 1. Local Development

```bash
pnpm dev                    # http://localhost:3000

# Or Docker
docker compose up -d app --build
```

---

## 2. First-time ECS Setup

### 2.1 SSH into ECS

```bash
ssh root@218.244.153.47
```

### 2.2 Install Docker

```bash
# Alibaba Cloud Linux / CentOS
yum install -y docker
systemctl enable docker && systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 2.3 Create deploy directory

```bash
mkdir -p /opt/blog/certs
cd /opt/blog
```

### 2.4 Upload config files from local

```bash
# Run from your local machine
scp docker-compose.yml nginx.conf root@218.244.153.47:/opt/blog/
scp .env.local root@218.244.153.47:/opt/blog/
```

### 2.5 SSL certificates (optional)

```bash
# Place your cert files
# certs/cert.pem  — certificate
# certs/key.pem   — private key
```

---

## 3. Deploy (Manual)

From your local machine, three steps:

```bash
# Step 1: Build image
./scripts/build.sh

# Step 2: Push to ACR
./scripts/push.sh

# Step 3: Deploy to ECS
./scripts/deploy.sh
```

Or with a specific tag:

```bash
./scripts/build.sh v1.0.0
./scripts/push.sh v1.0.0
./scripts/deploy.sh v1.0.0
```

What each script does:

| Script | What it does |
|--------|-------------|
| `build.sh` | Builds Docker image locally, tags as `ACR_REGISTRY/ACR_NAMESPACE/IMAGE_NAME:tag` |
| `push.sh` | Logs into ACR, pushes the image |
| `deploy.sh` | SSH into ECS, updates image tag in docker-compose.yml, pulls and restarts |

---

## 4. CI/CD (GitHub Actions)

Push to `main` triggers: build → push to ACR → SSH to ECS → pull & restart.

### GitHub Variables (non-sensitive)

Settings → Secrets and variables → Actions → **Variables** tab:

| Variable | Value |
|----------|-------|
| `ACR_REGISTRY` | `crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com` |
| `ACR_NAMESPACE` | `daolanx` |
| `ACR_USERNAME` | `daolanx` |
| `IMAGE_NAME` | `payload-notes` |
| `DEPLOY_PATH` | `/opt/blog` |

### GitHub Secrets (sensitive)

Settings → Secrets and variables → Actions → **Secrets** tab:

| Secret | Description |
|--------|-------------|
| `ACR_PASSWORD` | ACR login password |
| `ECS_HOST` | `218.244.153.47` |
| `ECS_USERNAME` | `root` |
| `ECS_SSH_KEY` | SSH private key for ECS |

---

## Architecture

```
Browser → nginx (:80/:443) → Next.js (:3000) → PostgreSQL + OSS
```

- **ISR**: Homepage and post pages cache for 60s, auto-regenerate
- **On-demand revalidation**: admin create/edit/delete triggers immediate cache invalidation

## SSL

```bash
sudo certbot certonly --standalone -d your-domain.com
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ./certs/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ./certs/key.pem
```

Then uncomment HTTPS block in `nginx.conf`.

---

**Last Updated:** 2026-06-24
