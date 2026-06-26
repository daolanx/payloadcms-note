# My Notes

A full-stack notes application with a visual CMS admin panel, deployed on Alibaba Cloud ECS.

## Highlights

- **ISR + On-demand Revalidation** — static pages for fast loading, auto-regenerated when content is edited in the admin panel
- **CMS-powered Admin** — Lexical rich text editor with Markdown shortcuts, image upload, and fixed toolbar for managing posts
- **OSS Image Pipeline** — responsive images with on-the-fly resize served from Alibaba Cloud OSS CDN

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 (App Router, Turbopack) |
| CMS | Payload CMS 3 |
| Database | PostgreSQL (Alibaba Cloud RDS) |
| Storage | Alibaba Cloud OSS (S3-compatible) |
| Styling | Tailwind CSS 4 + shadcn/ui |
| Rich Text | Lexical Editor |
| Language | TypeScript |

## Project Structure

```
├── src/
│   ├── app/
│   │   ├── (frontend)/          # Public pages
│   │   │   ├── layout.tsx       # HTML shell, fonts, Header
│   │   │   ├── page.tsx         # Homepage — post listing (ISR)
│   │   │   └── posts/[slug]/    # Post detail page (ISR)
│   │   ├── (payload)/admin/     # Payload CMS admin panel
│   │   └── api/
│   │       ├── [...slug]/       # Payload REST API
│   │       └── revalidate/      # On-demand revalidation endpoint
│   ├── components/
│   │   ├── header.tsx           # Sticky nav bar
│   │   └── post-image.tsx       # Responsive image (OSS loader)
│   ├── lib/
│   │   ├── image-loader.ts      # Next.js custom loader for OSS
│   │   ├── posts.ts             # Cached post fetching functions
│   │   └── utils.ts             # cn() utility
│   └── payload.config.ts        # Payload CMS configuration
├── scripts/
│   ├── build.sh                 # Build Docker image (amd64)
│   ├── push.sh                  # Push to ACR
│   ├── deploy.sh                # Deploy to ECS
│   └── setup-ecs.sh             # Initialize ECS server
├── compose.yaml                 # Local dev compose
├── compose.prod.yaml            # Production compose (no build config)
├── Dockerfile                   # Production multi-stage build
├── Dockerfile.dev               # Development with hot reload
└── nginx.conf                   # nginx reverse proxy config
```

## 1. Local Development

### Environment Variables

```bash
cp .env.example .env.local   # Create from template (first time only)
vim .env.local               # Fill in the values below
```

**App config** (required for local dev):

| Variable | Description |
|----------|-------------|
| `PAYLOAD_SECRET` | Payload CMS secret key |
| `DATABASE_URI` | PostgreSQL connection string |
| `NEXT_PUBLIC_SITE_URL` | Public site URL |
| `REVALIDATION_SECRET` | Secret for the revalidation API endpoint |
| `OSS_ENDPOINT` | Alibaba Cloud OSS endpoint |
| `OSS_BUCKET` | OSS bucket name |
| `OSS_ACCESS_KEY_ID` | OSS access key ID |
| `OSS_ACCESS_KEY_SECRET` | OSS access key secret |
| `NEXT_PUBLIC_OSS_ENDPOINT` | OSS endpoint (exposed to client for image loader) |
| `NEXT_PUBLIC_OSS_BUCKET` | OSS bucket (exposed to client for image loader) |

### Start Dev Server

```bash
pnpm dev                    # http://localhost:3000

# Or Docker (hot reload with compose watch)
docker compose --profile dev watch
```

## 2. Deployment (ECS)

> Prerequisites: local dev working, `.env.local` configured, SSH key to ECS ready.

### Deploy Config

In addition to the app config above, add these to your `.env.local`:

| Variable | Description |
|----------|-------------|
| `ACR_REGISTRY` | ACR public endpoint (used for local build/push; deploy script auto-switches to VPC) |
| `ACR_NAMESPACE` | ACR namespace |
| `ACR_USERNAME` | ACR username |
| `ACR_PASSWORD` | ACR login password (for non-interactive login) |
| `IMAGE_NAME` | ACR repository name |
| `ECS_HOST` | ECS server public IP |
| `ECS_USERNAME` | ECS SSH username |
| `DEPLOY_PATH` | Deploy directory on ECS (default: `/opt/notes`) |

### First-time ECS Setup

**Step 1: Setup SSH key authentication (recommended)**

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy public key to ECS (will prompt for password)
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@<ECS_HOST>

# Test passwordless login
ssh root@<ECS_HOST>
```

**Step 2: Initialize ECS server**

```bash
./scripts/setup-ecs.sh    # or: pnpm ecs:init
```

This script will:
- Create `/opt/notes` directory
- Install Docker (or Podman)
- Install Docker Compose plugin
- Upload `compose.yaml` to server

**Step 3: Start Podman socket (if using Podman)**

If your ECS uses Podman instead of Docker:

```bash
ssh root@<ECS_HOST>
sudo systemctl start podman.socket
sudo systemctl enable podman.socket
sudo touch /etc/containers/nodocker  # Suppress warning
```

### Manual Deployment

```bash
./scripts/build.sh          # Build image locally (linux/amd64)
./scripts/push.sh           # Push to ACR
./scripts/deploy.sh         # SSH to ECS, pull and restart
```

Or with a specific tag:

```bash
./scripts/build.sh v1.0.0
./scripts/push.sh v1.0.0
./scripts/deploy.sh v1.0.0
```

### GitHub Actions Deployment

Push to `main` triggers automatic deployment:

```bash
git push origin main
```

Pipeline: build → push to ACR → SSH to ECS → pull & restart.

## 3. Troubleshooting

### Podman socket not running

**Error:** `failed to connect to the docker API at unix:///run/podman/podman.sock`

**Solution:**
```bash
ssh root@<ECS_HOST>
sudo systemctl start podman.socket
sudo systemctl enable podman.socket
```

### ACR login failed during deploy

**Error:** `denied: requested access to the resource is denied`

**Causes:**
1. Wrong `ACR_PASSWORD` in `.env.local`
2. Image doesn't exist in ACR (need to build and push first)

**Solution:**
```bash
# Verify credentials manually
ssh root@<ECS_HOST>
docker login crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com

# Build and push image from local
./scripts/build.sh
./scripts/push.sh
```

### Architecture mismatch

**Error:** `no image found in image index for architecture amd64`

**Cause:** Image built on Mac (arm64) but ECS is amd64.

**Solution:** Build script already specifies `--platform linux/amd64`:
```bash
./scripts/build.sh  # Automatically builds for amd64
```

### YAML parse error on server

**Error:** `yaml: while parsing a block mapping`

**Cause:** `sed` commands corrupted `compose.yaml` on server.

**Solution:** Deploy script now uploads `compose.prod.yaml` (without `build:` config):
```bash
./scripts/deploy.sh  # Automatically uploads clean compose file
```

### Admin panel login fails silently (user: null)

**Symptoms:** Login returns HTTP 200 with valid token, but browser redirects back to `/admin/login`.

**Root cause:** PayloadCMS cookie auth requires the browser to send `Origin` or `Sec-Fetch-Site` header. Chrome doesn't send `Sec-Fetch-Site` for AJAX requests in HTTP environments, causing cookie auth to silently fail.

**Temporary fix (HTTP):** Nginx layer Origin injection in `nginx.conf`:
```nginx
proxy_set_header Origin "http://$host";
```

**Permanent fix:** Deploy with HTTPS + domain. Browsers send `Sec-Fetch-Site: same-origin` correctly over HTTPS. After that, restore `csrf: ['https://your-domain.com']` and remove the Nginx Origin injection.

See [docs/bug-payload-csrf-cookie-auth.md](docs/bug-payload-csrf-cookie-auth.md) for full analysis.

### Container healthcheck failing

Check container logs:
```bash
ssh root@<ECS_HOST>
cd /opt/notes
docker compose --profile prod logs app
```

### nginx exec format error

**Error:** `exec /docker-entrypoint.sh: exec format error`

**Cause:** nginx image is arm64 but ECS is amd64.

**Solution:** Docker Hub now serves multi-arch images correctly. If you still hit this, configure Docker mirror acceleration (see [Docker Hub Mirror Acceleration](https://docs.docker.com/engine/daemon/mirror/)) or pull explicitly with `docker pull --platform linux/amd64 nginx:alpine` on the ECS server.

### Podman and Docker credential separation

**Problem:** `podman login` succeeds but `docker-compose pull` fails with `denied`.

**Cause:** Podman and Docker have separate credential storage. `docker-compose` (called by `podman compose`) reads Docker's config, not Podman's.

**Solution:** Deploy script handles this by:
1. Login with both `podman login` and `docker login`
2. Generate proper `/root/.docker/config.json` with base64 encoded credentials

### ECS security group blocking access

**Error:** `This page isn't working` or `Empty reply from server`

**Solution:** Add inbound rules in ECS security group:
- TCP 80/80 (HTTP) — for nginx
- TCP 3000/3000 (App) — for direct access

### docker-compose variable warning

**Warning:** `The "Understar0" variable is not set`

**Cause:** `.env.local` has unescaped `$` in `ECS_PASSWORD=$Understar0`

**Solution:** Escape special characters in `.env.local`:
```bash
ECS_PASSWORD=\$Understar0
# or use single quotes in shell export
```

## 4. Container Management (Portainer)

For non-technical team members, we use Portainer as a visual container management interface.

### Access Portainer

```
http://<ECS_HOST>:9000
```

1. Open the URL in browser
2. Set admin password on first visit
3. Select **Local** environment
4. You can see all containers and manage them

### Portainer Features

- ✅ One-click container restart
- ✅ View container logs
- ✅ Start/stop containers
- ✅ View container status and resource usage
- ✅ No command line knowledge required

### Security Group

Make sure port 9000 is open in ECS security group:

| Protocol | Port | Source |
|----------|------|--------|
| TCP | 9000/9000 | 0.0.0.0/0 |

### Notes

- Portainer is installed automatically during first ECS setup
- The image is pulled from your ACR (amd64 version)
- Data is stored in Docker volume `portainer_data`

## 5. GitHub Actions Configuration

### GitHub Configuration

**Variables** (non-sensitive, Settings → Actions → Variables):

| Variable | Description |
|----------|-------------|
| `ACR_REGISTRY` | ACR endpoint |
| `ACR_NAMESPACE` | ACR namespace |
| `ACR_USERNAME` | ACR username |
| `IMAGE_NAME` | `payload-notes` |
| `DEPLOY_PATH` | `/opt/notes` |

**Secrets** (sensitive, Settings → Actions → Secrets):

| Secret | Description |
|--------|-------------|
| `ACR_PASSWORD` | ACR login password |
| `ECS_HOST` | ECS server public IP |
| `ECS_USERNAME` | ECS SSH username |
| `ECS_SSH_KEY` | SSH private key for ECS |

## 6. Architecture

```
Browser → nginx (:80/:443) → Next.js (:3000) → PostgreSQL + OSS
```

### ISR (Incremental Static Regeneration)

```
Build time:  generateStaticParams() → pre-render all /posts/[slug] pages
Edit time:   Payload afterChange hook → POST /api/revalidate → revalidatePath()
Runtime:     pages served from cache, auto-regenerate every 60s
```

### Image Loading

```
Payload media URL → next/image loader → OSS URL with resize param
http://localhost:3000/api/media/file/big.webp
  → https://bucket.oss-cn-beijing.aliyuncs.com/big.webp?x-oss-process=image/resize,w_640
```

### Payload CMS Collections

| Collection | Description |
|-----------|-------------|
| `posts` | Notes — title, slug, cover image, excerpt, rich text content, status, published date |
| `media` | Uploaded images — stored in OSS, public read access |
| `users` | Admin users — authentication enabled |

## SSL (Optional)

Two ways to set up HTTPS:

**Option A: Certbot on ECS (recommended)**

```bash
ssh root@<ECS_HOST>
certbot certonly --standalone -d your-domain.com
cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /opt/notes/certs/cert.pem
cp /etc/letsencrypt/live/your-domain.com/privkey.pem /opt/notes/certs/key.pem
docker compose -f /opt/notes/compose.yaml restart nginx
```

**Option B: Local certs, auto-upload via script**

Place `certs/cert.pem` and `certs/key.pem` locally, then run `pnpm ecs:init` — the script uploads them automatically.

After certificates are in place, uncomment the HTTPS block in `nginx.conf`.

> **Important:** HTTPS is required for proper admin panel cookie authentication. See [Troubleshooting → Admin panel login fails](#admin-panel-login-fails-silent-user-null) for details.

## License

MIT
