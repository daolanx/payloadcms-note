# My Blog

A blog built with Next.js 16, Payload CMS 3, PostgreSQL, and Alibaba Cloud OSS.

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
│   ├── (frontend)/          # Public blog pages
│   │   ├── layout.tsx       # HTML shell, fonts, Header
│   │   ├── page.tsx         # Homepage — post listing (SSG)
│   │   └── posts/[slug]/    # Post detail page (SSG)
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

## Getting Started

### Prerequisites

- Node.js 22+
- pnpm
- PostgreSQL database

### Setup

```bash
# Install dependencies
pnpm install

# Copy environment variables
cp .env.example .env.local
# Edit .env.local with your actual credentials

# Start dev server
pnpm dev
```

Visit `http://localhost:3000` for the blog, `http://localhost:3000/admin` for the CMS admin.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `PAYLOAD_SECRET` | Payload CMS secret key |
| `DATABASE_URI` | PostgreSQL connection string |
| `NEXT_PUBLIC_SITE_URL` | Public site URL (e.g. `https://blog.example.com`) |
| `REVALIDATION_SECRET` | Secret for the revalidation API endpoint |
| `OSS_ENDPOINT` | Alibaba Cloud OSS endpoint |
| `OSS_BUCKET` | OSS bucket name |
| `OSS_ACCESS_KEY_ID` | OSS access key ID |
| `OSS_ACCESS_KEY_SECRET` | OSS access key secret |
| `NEXT_PUBLIC_OSS_ENDPOINT` | Same as OSS_ENDPOINT (exposed to client for image loader) |
| `NEXT_PUBLIC_OSS_BUCKET` | Same as OSS_BUCKET (exposed to client for image loader) |

## Architecture

### SSG + On-demand Revalidation

```
Build time:  generateStaticParams() → pre-render all /posts/[slug] pages
Edit time:   Payload afterChange hook → POST /api/revalidate → revalidatePath()
Runtime:     pages served from cache until next edit
```

### Image Loading

```
Payload media URL → next/image loader → OSS URL with resize param
http://localhost:3000/api/media/file/big.webp
  → https://bucket.oss-cn-beijing.aliyuncs.com/big.webp?x-oss-process=image/resize,w_640
```

Small devices get small images, large devices get large ones. OSS handles format conversion and CDN caching.

### Payload CMS Collections

| Collection | Description |
|-----------|-------------|
| `posts` | Blog posts — title, slug, cover image, excerpt, rich text content, status, published date |
| `media` | Uploaded images — stored in OSS, public read access |
| `users` | Admin users — authentication enabled |

## Production Build

```bash
pnpm build
pnpm start
```

## Deployment (Docker + Alibaba Cloud ECS)

Automated via GitHub Actions. Push to `main` triggers build + deploy.

### How It Works

```
git push → GitHub Actions → build Docker image → push to ACR → ECS pulls & restarts
```

- **Build**: Docker multi-stage build on GitHub runners (not ECS)
- **Registry**: Alibaba Cloud Container Registry (ACR)
- **Runtime**: Docker Compose (app + nginx)

### Setup

**1. Create Alibaba Cloud ACR namespace and repository:**

1. Go to [ACR Console](https://cr.console.aliyun.com/)
2. Create a **namespace** (e.g. `my-blog`)
3. Create a **repository** under that namespace (name: `blog`)

**2. Add GitHub Secrets** (Settings → Secrets → Actions):

| Secret | Description | Example |
|--------|-------------|---------|
| `ECS_HOST` | ECS public IP | `47.100.xxx.xxx` |
| `ECS_USERNAME` | SSH user | `root` |
| `ECS_SSH_KEY` | SSH private key | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `ACR_NAMESPACE` | ACR namespace | `my-blog` |
| `ACR_USERNAME` | ACR login name | `your-aliyun-account` |
| `ACR_PASSWORD` | ACR login password | `your-aliyun-password` |

**3. First-time ECS setup** (run once):

```bash
# SSH into ECS
ssh root@your-ecs-ip

# Install Docker
apt update && apt install -y docker.io docker-compose-plugin
systemctl enable --now docker

# Create project directory
mkdir -p /opt/blog

# Copy config files from local machine
scp docker-compose.yml nginx.conf root@YOUR_ECS_IP:/opt/blog/

# Create environment variables on ECS
cat > /opt/blog/.env.local << 'EOF'
PAYLOAD_SECRET=your-secret
NEXT_PUBLIC_SITE_URL=https://your-domain.com
REVALIDATION_SECRET=your-revalidation-secret
DATABASE_URI=postgres://user:password@host:5432/payload
OSS_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com
OSS_BUCKET=your-bucket
OSS_ACCESS_KEY_ID=your-key-id
OSS_ACCESS_KEY_SECRET=your-key-secret
NEXT_PUBLIC_OSS_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com
NEXT_PUBLIC_OSS_BUCKET=your-bucket
DOCKER_REGISTRY=registry.cn-hangzhou.aliyuncs.com/your-namespace
IMAGE_TAG=latest
EOF

# Edit .env.local with your actual values
vim /opt/blog/.env.local

# Start the app
cd /opt/blog && docker compose up -d
```

**4. Deploy** — just push:

```bash
git push origin main
```

### ECS Prerequisites

- Docker + Docker Compose installed
- SSH access from GitHub Actions
- `.env.local` on ECS at `/opt/blog/.env.local`

### Useful Commands

```bash
# On ECS, view logs
docker compose -f /opt/blog/docker-compose.yml logs -f app

# Restart app
docker compose -f /opt/blog/docker-compose.yml restart app

# Rollback to previous version
docker compose -f /opt/blog/docker-compose.yml up -d --no-deps app
```

## License

MIT
