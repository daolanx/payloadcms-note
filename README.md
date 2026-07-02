# My Notes

A self-hosted CMS-powered notes application deployed on Alibaba Cloud ECS, featuring ISR static acceleration, Lexical rich text editing, and OSS image pipeline.

# Cloud Service Rationale

This is a simple content site. The goal is to keep costs low, meet functional requirements, and minimize operational complexity. ECS + OSS is sufficient for this use case.

- **OSS** —Essential for storing image assets, serving responsive images, and backing up data.
- **Database** —Payload CMS works better with Postgres, but SQLite is simpler, cheaper, and performant enough for this project. Data backups can be handled via file-level copies.


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
Browser → Nginx → Docker → SQLite + OSS
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
| `pnpm docker:build` | Build Docker image |
| `pnpm docker:push` | Push latest local image to ACR |

## Deployment

### 1. Migrate Database Changes

In development, Payload uses `push: true` to auto-sync your schema to SQLite on every startup — no manual step needed. In production, `push` is intentionally disabled for safety, so you must generate a migration file manually when the schema changes. The migration file is bundled into the Docker image and applied automatically at container startup via `prodMigrations`.

If no schema changes, skip this step.

```bash
pnpm payload:migrate:create
```

### 2. Build & Push Image

Choose either option to build and push the Docker image.

**Option A: CI Build & Push (Recommended)**

Pushing a tag to the repo triggers GitHub Actions to automatically build and push the Docker image to ACR.

```bash
git tag v1.2.5
git push origin v1.2.5
```

**Option B: Local Build & Push**

Alternatively, build and push the Docker image locally.

First time, login to ACR locally:

```bash
docker login <ACR_REGISTRY> -u <username>
```
Then run:

```bash
pnpm docker:build                    # tag: commitHash-timestamp
pnpm docker:push                     # push to ACR

# Or specify a version tag (-t short form also works)
pnpm docker:build --tag v1.2.5
pnpm docker:push --tag v1.2.5
```

### 3. Initialize ECS Environment

For simplicity, use the BaoTa Panel (bundled with Alibaba Cloud ECS) to set up the environment:

- Find and install the BaoTa Panel from the ECS instance details page
- Use BaoTa to install Docker, and configure the registry address to point to ACR
- Use BaoTa to install Nginx

### 4. Initialize Application on ECS

Run the init script locally. It uploads the deploy script and environment file to ECS, and creates the data directory.

```bash
bash scripts/init-ecs.sh
```

### 5. Pull Image and Start Container

SSH into ECS and run the deploy script:

```bash
ssh root@$ECS_HOST
bash /opt/notes/deploy.sh --tag <image_tag>
```

### 6. Configure Nginx

Configure Nginx in the BaoTa Panel to reverse proxy to `127.0.0.1:3000`.

### 7. Backup

- Database backup: BaoTa → Scheduled Tasks → Backup Directory → select `/opt/notes/db/`.
- Image backup: Images are stored on OSS, no backup needed.


## Operations

### Update Deploy

Push a new git tag to trigger CI build for a new Docker image, then SSH into ECS and run:

```bash
bash /opt/notes/deploy.sh --tag <new_image_tag>
```

### Troubleshooting

```bash
docker logs my-notes
docker ps -a
docker exec -it my-notes sh
docker restart my-notes
```
Or use the BaoTa Panel to inspect and manage the container.

## Pitfalls

- [SQLite Production Migration](docs/sqlite-production-migration.md) — `push: true` doesn't work in production, use `prodMigrations` instead
- [General Pitfalls](docs/pitfalls.md) — other real-world issues encountered during development and deployment

## License

MIT
