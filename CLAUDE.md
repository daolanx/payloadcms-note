# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Next.js 16 + Payload CMS 3 + SQLite + Tailwind CSS 4 + shadcn/ui. Chinese-language notes app ("My Notes") self-hosted on Alibaba Cloud ECS with nginx SSL termination, OSS image storage with on-the-fly resize, and ISR for performance.

**Read `AGENTS.md`** — Next.js 16 has breaking changes; check `node_modules/next/dist/docs/` before writing unfamiliar Next.js code. Also read `docs/pitfalls.md` for real-world issues encountered during development and deployment.

## Commands

```bash
pnpm dev          # Start dev server (port 3000, Turbopack)
pnpm build        # Production build
pnpm start        # Start production server
pnpm lint         # ESLint (flat config, eslint-config-next)
pnpm payload:gen-importmap  # Regenerate Payload admin import map
```

Package manager: `pnpm@9.15.9`. No test framework is configured.

## Architecture

### Route Groups (critical layout structure)

- **`(frontend)/`** — Public pages. Its `layout.tsx` owns `<html>` and `<body>` tags with Geist fonts and global CSS.
- **`(payload)/trail/`** — Payload CMS admin panel (accessible at `/trail`). Its auto-generated `layout.tsx` uses `RootLayout` from `@payloadcms/next/layouts` which renders its own `<html>`/`<body>`.
- **Root `layout.tsx`** — Returns `<>{children}</>` only (no `<html>`/`<body>`). This is intentional to avoid nested HTML conflicts between the two route groups.

### ISR + Revalidation Flow

Pages use ISR with `revalidate = 60`. On-demand revalidation via Payload hooks:

```
Payload afterChange/afterDelete hooks → POST /api/revalidate (x-revalidate-secret header)
→ revalidatePath('/') + revalidatePath('/posts/[slug]', 'page')
```

Docker build uses `next build --experimental-build-mode compile` to skip pre-rendering (no DB needed at build time). Pages render on-demand at runtime.

### Image Loading (OSS)

Payload stores media metadata in the `media` collection; actual files live in Alibaba Cloud OSS. A custom image loader in `src/lib/image-loader.ts` converts Payload URLs to OSS virtual-hosted style with on-the-fly resize:

```
Payload URL:  /api/media/file/big.webp
  → OSS URL:  https://{bucket}.{endpoint}/big.webp?x-oss-process=image/resize,w_{width}
```

The `PostImage` component (`src/components/post-image.tsx`) wraps `next/image` with this loader.

### Payload CMS Setup

- **Config**: `src/payload.config.ts` — SQLite adapter, Lexical editor with `FixedToolbarFeature`, `@payloadcms/storage-s3` plugin for OSS, 3 collections (users, posts, media).
- **Collections**:
  - `users` — auth (JWT-based, default secure cookies), fields: name, gender (select), avatar (upload→media)
  - `posts` — title, slug (unique), coverImage (upload), excerpt, content (richText), status (draft/published), publishedAt (sidebar). Has `afterChange`/`afterDelete` hooks that POST to `/api/revalidate`.
  - `media` — image/* only, public read, fields: alt
- **API route**: `src/app/api/[...slug]/route.ts` — Auto-generated, do not edit.
- **Admin layout**: `src/app/(payload)/trail/[[...segments]]/layout.tsx` — Auto-generated, imports `@payloadcms/next/css` for admin styles.
- **importMap**: `src/app/(payload)/trail/importMap.js` — Maps Payload component paths to imports. Regenerate with `pnpm payload:gen-importmap`.

### Data Fetching

`src/lib/posts.ts` wraps Payload queries with `unstable_cache` (tags: `['posts']`). The `Post` interface defines the shape used across pages.

### Styling

- **Tailwind CSS 4** via `@tailwindcss/postcss` (no `tailwind.config.*` file needed).
- **shadcn/ui** components in `src/components/ui/` — uses `@base-ui/react` (NOT Radix). Button does NOT support `asChild` prop; use `buttonVariants()` + `Link` pattern instead.
- **Payload admin styles**: Loaded via `import '@payloadcms/next/css'` in the admin layout. Do NOT use SCSS imports for Payload styles.
- **CSS files**: `src/app/globals.css` and `src/app/(frontend)/globals.css` (both needed — root and frontend layout respectively).

### Key Gotchas

- **SQLite in production**: `push: true` only works in development. Use `prodMigrations: migrations` for production. See [docs/sqlite-production-migration.md](docs/sqlite-production-migration.md).
- **pnpm strict mode**: `@payloadcms/ui` must be listed as a direct dependency, otherwise it's not resolvable from project code.
- **Payload CLI ESM bug**: `payload generate:types` crashes with `ERR_REQUIRE_ASYNC_MODULE` on Node 20/22. Use `pnpm payload:gen-importmap` for importMap generation.
- **Schema changes**: Adding required columns to existing tables triggers a confirmation prompt. Use `PAYLOAD_DROP_DATABASE=true` env var to reset during development.
- **Media uploads**: Uses `@payloadcms/storage-s3` plugin with Alibaba Cloud OSS. Files stored remotely, not on local disk.

### Path Aliases

- `@/*` → `./src/*`
- `@payload-config` → `./src/payload.config.ts`

### Docker

- `docker/` — production deployment.
  - `Dockerfile` — multi-stage build with standalone output, pnpm store cache mount.
  - `compose.yaml` — app service, SQLite data bind mount to `/opt/notes/db`.
  - `build.sh` — build Docker image (used by both local and CI).
  - `push.sh` — push image to ACR.

### CI/CD

GitHub Actions workflow (`.github/workflows/build.yml`): push tag → build Docker image → push to ACR. Deployment is manual via BaoTa Panel.
