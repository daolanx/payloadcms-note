# Deployment Guide

## Architecture

- **Database**: PostgreSQL (cloud)
- **Media Storage**: Alibaba Cloud OSS (S3-compatible)
- **Runtime**: Next.js standalone + nginx
- **CI/CD**: GitHub Actions → ACR → ECS

## Quick Start

### Local Development

```bash
pnpm install
pnpm dev
```

### Docker Local Testing

```bash
# Start app only (without nginx)
docker compose up -d app --build

# View logs
docker compose logs -f app

# Stop
docker compose down
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PAYLOAD_SECRET` | Yes | Payload CMS encryption key |
| `DATABASE_URI` | Yes | PostgreSQL connection string |
| `NEXT_PUBLIC_SITE_URL` | Yes | Site URL (e.g. `https://your-domain.com`) |
| `OSS_ENDPOINT` | Yes | OSS endpoint (e.g. `oss-cn-hangzhou.aliyuncs.com`) |
| `OSS_BUCKET` | Yes | OSS bucket name |
| `OSS_ACCESS_KEY_ID` | Yes | OSS access key ID |
| `OSS_ACCESS_KEY_SECRET` | Yes | OSS access key secret |
| `REVALIDATION_SECRET` | Yes | ISR revalidation secret |

## Production Deployment

### 1. ECS Server Setup

```bash
# SSH into ECS
ssh root@your-ecs-host

# Create deploy directory
mkdir -p /opt/blog && cd /opt/blog

# Create .env.local with all required env vars
nano .env.local
```

### 2. Configure SSL Certificates

```bash
mkdir -p certs
# Place cert.pem and key.pem in certs/
```

### 3. Configure nginx

Edit `nginx.conf` — uncomment the HTTPS server block and set your domain:

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ...
}
```

### 4. Start Services

```bash
docker compose up -d
docker compose ps
docker compose logs -f
```

## CI/CD (GitHub Actions)

Push to `main` triggers automatic deployment:

1. Builds Docker image
2. Pushes to Alibaba Cloud ACR
3. SSH into ECS, pulls new image, restarts services

### Required Secrets

| Secret | Description |
|--------|-------------|
| `ACR_NAMESPACE` | ACR namespace |
| `ACR_USERNAME` | ACR login username |
| `ACR_PASSWORD` | ACR login password |
| `ECS_HOST` | ECS server IP |
| `ECS_USERNAME` | ECS SSH username |
| `ECS_SSH_KEY` | ECS SSH private key |

## Verification

```bash
# Check services
docker compose ps

# Test HTTP
curl -I http://your-domain.com

# Test API
curl https://your-domain.com/api/health
```

## Troubleshooting

### nginx 502 Bad Gateway

```bash
docker compose ps
docker compose logs app
docker compose restart app
```

### Container Won't Start

```bash
docker compose logs app
docker stats
```

### SSL Certificate Issues

```bash
ls -la certs/
openssl x509 -in certs/cert.pem -noout -dates
docker compose exec nginx nginx -t
```

---

**Last Updated:** 2026-06-24
