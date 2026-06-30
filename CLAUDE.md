# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Next.js 16 + Payload CMS 3 + PostgreSQL + Tailwind CSS 4 + shadcn/ui. Chinese-language notes app ("My Notes") self-hosted on Alibaba Cloud ECS with nginx SSL termination, OSS image storage with on-the-fly resize, and ISR for performance.

**Read `AGENTS.md`** — Next.js 16 has breaking changes; check `node_modules/next/dist/docs/` before writing unfamiliar Next.js code. Also read `docs/pitfalls.md` for real-world issues encountered during development and deployment.

## Commands

```bash
pnpm dev          # Start dev server (port 3000, Turbopack)
pnpm build        # Production build
pnpm start        # Start production server
pnpm lint         # ESLint (flat config, eslint-config-next)

# Payload importMap generation (workaround for CLI ESM bug)
pnpm payload:gen-importmap

# Docker preview (local production test)
pnpm docker:dev
```

Package manager: `pnpm@9.15.9`. No test framework is configured.

## Architecture

### Route Groups (critical layout structure)

- **`(frontend)/`** — Public pages. Its `layout.tsx` owns `<html>` and `<body>` tags with Geist fonts and global CSS.
- **`(payload)/admin/`** — Payload CMS admin panel. Its auto-generated `layout.tsx` uses `RootLayout` from `@payloadcms/next/layouts` which renders its own `<html>`/`<body>`.
- **Root `layout.tsx`** — Returns `<>{children}</>` only (no `<html>`/`<body>`). This is intentional to avoid nested HTML conflicts between the two route groups.

### ISR + Revalidation Flow

Pages use ISR with `revalidate = 60`. On-demand revalidation via Payload hooks:

```
Payload afterChange/afterDelete hooks → POST /api/revalidate (x-revalidate-secret header)
→ revalidatePath('/') + revalidatePath('/posts/[slug]', 'page')
```

`getAllPostSlugs()` skips DB query when `IS_DOCKER_BUILD=true` (no DB during Docker build); pages render on-demand via ISR on first request.

### Image Loading (OSS)

Payload stores media metadata in the `media` collection; actual files live in Alibaba Cloud OSS. A custom image loader in `src/lib/image-loader.ts` converts Payload URLs to OSS virtual-hosted style with on-the-fly resize:

```
Payload URL:  /api/media/file/big.webp
  → OSS URL:  https://{bucket}.{endpoint}/big.webp?x-oss-process=image/resize,w_{width}
```

The `PostImage` component (`src/components/post-image.tsx`) wraps `next/image` with this loader.

### Payload CMS Setup

- **Config**: `src/payload.config.ts` — PostgreSQL adapter, Lexical editor with `FixedToolbarFeature`, `@payloadcms/storage-s3` plugin for OSS, 3 collections (users, posts, media).
- **Collections**:
  - `users` — auth (session-based, cookies secure:false), fields: name, gender (select), avatar (upload→media)
  - `posts` — title, slug (unique), coverImage (upload), excerpt, content (richText), status (draft/published), publishedAt (sidebar). Has `afterChange`/`afterDelete` hooks that POST to `/api/revalidate`.
  - `media` — image/* only, public read, fields: alt
- **API route**: `src/app/api/[...slug]/route.ts` — Auto-generated, do not edit.
- **Admin layout**: `src/app/(payload)/admin/[[...segments]]/layout.tsx` — Auto-generated, imports `@payloadcms/next/css` for admin styles.
- **importMap**: `src/app/(payload)/admin/importMap.ts` — Maps Payload component paths to imports. `RenderServerComponent` must be imported from `@payloadcms/ui/elements/RenderServerComponent` (not `@payloadcms/ui` directly). Regenerate with `pnpm payload:gen-importmap`.

### Data Fetching

`src/lib/posts.ts` wraps Payload queries with `unstable_cache` (tags: `['posts']`). The `Post` interface defines the shape used across pages.

### Styling

- **Tailwind CSS 4** via `@tailwindcss/postcss` (no `tailwind.config.*` file needed).
- **shadcn/ui** components in `src/components/ui/` — uses `@base-ui/react` (NOT Radix). Button does NOT support `asChild` prop; use `buttonVariants()` + `Link` pattern instead.
- **Payload admin styles**: Loaded via `import '@payloadcms/next/css'` in the admin layout. Do NOT use SCSS imports for Payload styles.
- **CSS files**: `src/app/globals.css` and `src/app/(frontend)/globals.css` (both needed — root and frontend layout respectively).

### Key Gotchas

- **pnpm strict mode**: `@payloadcms/ui` must be listed as a direct dependency, otherwise it's not resolvable from project code.
- **Payload CLI ESM bug**: `payload generate:types`, `payload generate:importmap` etc. crash with `ERR_REQUIRE_ASYNC_MODULE` on Node 20/22. Type generation and importMap generation must be done manually or via custom scripts.
- **Schema changes**: Adding required columns to existing tables triggers a confirmation prompt. Use `PAYLOAD_DROP_DATABASE=true` env var to reset during development.
- **Media uploads**: Uses `@payloadcms/storage-s3` plugin with Alibaba Cloud OSS. Files stored remotely, not on local disk.

### Path Aliases

- `@/*` → `./src/*`
- `@payload-config` → `./src/payload.config.ts`

### Docker

- `docker/production/` — production self-contained directory (Dockerfile, compose, nginx, certs, 502 page).
  - `Dockerfile` — multi-stage build with standalone output, pnpm store cache mount.
  - `compose.yaml` — app + nginx services, volume paths reference files in same directory.
  - `nginx.conf` — HTTPS reverse proxy with SSL termination, HTTP→HTTPS redirect, CSRF fix for Payload, 502 maintenance page.
  - `502.html` — maintenance page shown during backend failures.
  - `certs/` — SSL certificates (gitignored, only needed on ECS for nginx).
- `docker/development/` — development self-contained directory.
  - `Dockerfile` — development image with `WATCHPACK_POLLING=true` for container HMR.
  - `compose.yaml` — dev service with watch mode, build context is project root (`../..`).
- `pnpm-workspace.yaml` needs `packages: ['.']` temporarily during `pnpm install` in build context.

### CI/CD

GitHub Actions workflow (`.github/workflows/deploy.yml`): push to `main` → build Docker image → push to ACR → SSH to ECS → pull & restart. Uses BuildKit GHA cache for layer caching.
