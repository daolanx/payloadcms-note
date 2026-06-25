# My Notes

A notes app built with Next.js 16, Payload CMS 3, PostgreSQL, and Alibaba Cloud OSS.

## Features

- **SSG (Static Site Generation)** — pages are pre-rendered at build time, only regenerate on content edit
- **Payload CMS Admin** — rich text editor with Markdown shortcuts, image upload, fixed toolbar
- **OSS Image Optimization** — responsive images served directly from Alibaba Cloud OSS CDN
- **On-demand Revalidation** — editing posts in admin auto-triggers page regeneration
- **Lexical Editor** — bold, italic, headings, lists, links, blockquotes, image upload, and more

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
src/
├── app/
│   ├── (frontend)/          # Public pages
│   │   ├── layout.tsx       # HTML shell, fonts, Header
│   │   ├── page.tsx         # Homepage — post listing (ISR)
│   │   └── posts/[slug]/    # Post detail page (ISR)
│   ├── (payload)/admin/     # Payload CMS admin panel
│   └── api/
│       ├── [...slug]/       # Payload REST API
│       └── revalidate/      # On-demand revalidation endpoint
├── components/
│   ├── header.tsx           # Sticky nav bar
│   └── post-image.tsx       # Responsive image (OSS loader)
├── lib/
│   ├── image-loader.ts      # Next.js custom loader for OSS
│   ├── posts.ts             # Cached post fetching functions
│   └── utils.ts             # cn() utility
└── payload.config.ts        # Payload CMS configuration
```

## Environment Variables

```bash
cp .env.example .env.local
# Fill in all values — both app config and deploy config
```

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
| `ACR_REGISTRY` | ACR endpoint |
| `ACR_NAMESPACE` | ACR namespace |
| `ACR_USERNAME` | ACR username |
| `IMAGE_NAME` | ACR repository name |
| `ECS_HOST` | ECS server public IP |
| `ECS_USERNAME` | ECS SSH username |
| `DEPLOY_PATH` | Deploy directory on ECS |

## 1. Local Development

```bash
pnpm dev                    # http://localhost:3000

# Or Docker (hot reload with compose watch)
docker compose --profile dev watch
```

## 2. ECS Initialization

> Run on your **local machine** (not ECS). Prerequisites: repo cloned, SSH key configured.

```bash
# 1. Fill in .env.local with ECS_HOST and other deploy config
cp .env.example .env.local
vim .env.local

# 2. Run setup
./scripts/setup-ecs.sh    # or: pnpm ecs:init
```

## 3. Manual Deployment

Run three commands from your local machine:

```bash
./scripts/build.sh          # Build image locally
./scripts/push.sh           # Push to ACR
./scripts/deploy.sh         # SSH to ECS, pull and restart
```

Or with a specific tag:

```bash
./scripts/build.sh v1.0.0
./scripts/push.sh v1.0.0
./scripts/deploy.sh v1.0.0
```

## 4. GitHub Actions Deployment

Push to `main` triggers automatic deployment:

```bash
git push origin main
```

Pipeline: build → push to ACR → SSH to ECS → pull & restart.

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

## Architecture

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

## License

MIT
