# Deployment Guide

## Quick Start

### Local Development

```bash
# Install dependencies
pnpm install

# Start development server
pnpm dev
```

### Docker Local Testing

```bash
# Start web service only (without nginx)
pnpm docker:dev

# View logs
pnpm docker:logs

# Stop services
pnpm docker:down
```

## Production Deployment

### 1. Environment Setup

Create a `.env` file:

```bash
# Required: Payload CMS secret key (change to a strong password)
PAYLOAD_SECRET=your-super-secret-key-here

# Optional: Site URL
NEXT_PUBLIC_SITE_URL=https://your-domain.com
```

### 2. Configure SSL Certificates

```bash
# Create certificates directory
mkdir -p certs

# Place SSL certificates in the certs directory
# certs/fullchain.pem  - Certificate chain
# certs/privkey.pem    - Private key
```

**Obtain free SSL certificates:**

```bash
# Using certbot (Let's Encrypt)
sudo certbot certonly --standalone -d your-domain.com

# Certificate file locations
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ./certs/
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ./certs/
sudo chmod 644 certs/*.pem
```

### 3. Enable nginx Service

Edit `docker-compose.yml` and uncomment the nginx service:

```yaml
services:
  web:
    build: .
    restart: always
    ports:
      - "3000:3000"
    volumes:
      - sqlite-data:/app/data
      - media-data:/app/media
    environment:
      - NODE_ENV=production
      - DATABASE_URI=file:./data/database.db
      - PAYLOAD_SECRET=${PAYLOAD_SECRET:-change-me-in-production}
      - NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL:-http://localhost:3000}
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) }).on('error', () => process.exit(1))"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./certs:/etc/nginx/certs
      - media-data:/media:ro
    depends_on:
      web:
        condition: service_healthy

volumes:
  sqlite-data:
  media-data:
```

### 4. Start Services

```bash
# Build and start all services
pnpm docker:up

# Check service status
pnpm docker:ps

# View logs
pnpm docker:logs

# Stop services
pnpm docker:down
```

### 5. Verify Deployment

```bash
# Check service health status
docker compose ps

# Test HTTP access
curl -I http://your-domain.com

# Test HTTPS access
curl -I https://your-domain.com

# Check if API is working
curl https://your-domain.com/api/health
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PAYLOAD_SECRET` | Yes | Payload CMS encryption key, must change for production |
| `NEXT_PUBLIC_SITE_URL` | No | Site URL, used for SEO and callbacks |
| `DATABASE_URI` | No | SQLite database path, default `file:./data/database.db` |
| `NODE_ENV` | No | Runtime environment, default `production` |

### Port Configuration

| Port | Service | Description |
|------|---------|-------------|
| 80 | nginx | HTTP (auto-redirects to HTTPS) |
| 443 | nginx | HTTPS |
| 3000 | Next.js | Application service (internal access) |

### Data Persistence

| Volume | Description |
|--------|-------------|
| `sqlite-data` | SQLite database files |
| `media-data` | Uploaded media files |

## Troubleshooting

### 1. Database File Permission Issues

```bash
# Check container user
docker compose exec web whoami

# Fix data directory permissions
docker compose exec web chmod -R 755 /app/data
docker compose exec web chmod -R 755 /app/media
```

### 2. Media Upload Failures

```bash
# Check media directory permissions
docker compose exec web ls -la /app/media

# Fix permissions
docker compose exec web chown -R nextjs:nodejs /app/media
```

### 3. nginx 502 Bad Gateway

```bash
# Check if web service is running
pnpm docker:ps

# View web service logs
pnpm docker:logs

# Restart services
pnpm docker:restart web nginx
```

### 4. SSL Certificate Issues

```bash
# Check certificate files
ls -la certs/

# Verify certificate validity
openssl x509 -in certs/fullchain.pem -noout -dates

# Check nginx configuration
docker compose exec nginx nginx -t
```

### 5. Container Won't Start

```bash
# View detailed error messages
pnpm docker:logs

# Check resource usage
docker stats

# Clean up old images
pnpm docker:clean
```

## Updating Deployment

```bash
# Pull latest code
git pull

# Rebuild and restart
pnpm docker:up

# Clean up old images
pnpm docker:clean
```

## Backup & Recovery

### Quick Commands

```bash
pnpm db:backup              # Backup database to ./backups/
pnpm backup:list            # List all local backups
pnpm db:restore <file>      # Restore database
pnpm backup:media <file>    # Restore media files
pnpm backup:full <file>     # Full restore (database + media)
pnpm backup:oss latest      # Restore latest backup from OSS
pnpm backup:oss:list        # List backups on OSS
```

### Backup Database

```bash
# Create local backup (with timestamp)
pnpm db:backup
# ✓ Backup saved to ./backups/database-20260622-143000.db
```

### Restore Database

```bash
# Option 1: Using pnpm command
pnpm db:restore ./backups/database-20260622.db

# Option 2: Using restore script directly
./scripts/restore.sh db ./backups/database-20260622.db

# Current database is auto-backed up before restore
```

### Restore Media Files

```bash
# Restore media from tar.gz backup
pnpm backup:media ./backups/media-backup-20260622.tar.gz
```

### Full Restore (Database + Media)

```bash
# Restore from full backup archive (contains database.db + media.tar.gz)
pnpm backup:full ./backups/backup-20260622-120000.tar.gz
```

### Restore from Alibaba Cloud OSS

```bash
# First configure OSS info in .env
# OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
# OSS_BUCKET=your-bucket
# OSS_ACCESS_KEY_ID=xxx
# OSS_ACCESS_KEY_SECRET=xxx

# List backups on OSS
pnpm backup:oss:list

# Restore latest backup
pnpm backup:oss latest

# Restore specific backup
pnpm backup:oss backup-20260622-120000.tar.gz
```

### Manual Media Volume Export/Import

```bash
# Export
docker run --rm -v media-data:/media -v $(pwd):/backup alpine tar czf /backup/media-backup-$(date +%Y%m%d).tar.gz -C /media .

# Import
docker run --rm -v media-data:/media -v $(pwd):/backup alpine tar xzf /backup/media-backup-20260622.tar.gz -C /media
```

### Backup File Types

| File Type | Description |
|-----------|-------------|
| `database-YYYYMMDD.db` | Standalone database file |
| `*.tar.gz` | Full backup archive containing `database.db` + `media.tar.gz` |
| OSS `backup-*.tar.gz` | Auto-uploaded full backups on Alibaba Cloud OSS |

## Performance Optimization

### 1. Enable Gzip Compression

nginx.conf is configured with Gzip. Ensure these types are compressed:

```nginx
gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript image/svg+xml;
```

### 2. Static Asset Caching

```nginx
# Next.js static assets (30-day cache)
location /_next/static/ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}

# Media files (30-day cache)
location /media/ {
    expires 30d;
    add_header Cache-Control "public";
}
```

### 3. Database Optimization

SQLite default configuration in Docker is sufficient. To optimize, modify `DATABASE_URI`:

```bash
# WAL mode (recommended)
DATABASE_URI=file:./data/database.db?mode=ro
```

## Monitoring

### Health Checks

```bash
# Manually check service status
pnpm docker:ps

# View resource usage
docker stats
```

### Log Management

```bash
# View real-time logs
pnpm docker:logs

# View specific service logs
pnpm docker:logs web
pnpm docker:logs nginx

# Limit log size (configure in docker-compose.yml)
services:
  web:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## Security Recommendations

1. **Change default passwords**: Ensure `PAYLOAD_SECRET` uses a strong password
2. **Limit port exposure**: Only expose necessary ports (80, 443)
3. **Use non-root user**: Dockerfile configured with `nextjs` user
4. **Regular updates**: Update base images and dependencies regularly
5. **Enable HTTPS**: Must enable SSL for production
6. **Backup data**: Regularly backup database and media files

## Support

If you encounter issues, please check:

1. Docker and Docker Compose versions
2. System resources (CPU, memory, disk space)
3. Network connectivity and firewall settings
4. SSL certificate validity
5. Environment variable configuration

---

**Last Updated:** 2026-06-22
