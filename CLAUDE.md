# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Next.js 16 + Payload CMS 3 + SQLite + Tailwind CSS 4 + shadcn/ui. Chinese-language user management demo.

## Commands

```bash
pnpm dev          # Start dev server (port 3000)
pnpm build        # Production build
pnpm start        # Start production server
pnpm lint         # ESLint

# Docker (local test, no nginx)
docker compose up -d web --build
docker compose down

# Docker (full stack with nginx, needs certs/ directory)
docker compose up -d --build
```

## Architecture

### Route Groups (critical layout structure)

- **`(frontend)/`** — Public pages. Its `layout.tsx` owns `<html>` and `<body>` tags with Geist fonts and global CSS.
- **`(payload)/admin/`** — Payload CMS admin panel. Its auto-generated `layout.tsx` uses `RootLayout` from `@payloadcms/next/layouts` which renders its own `<html>`/`<body>`.
- **Root `layout.tsx`** — Returns `<>{children}</>` only (no `<html>`/`<body>`). This is intentional to avoid nested HTML conflicts between the two route groups.

### Payload CMS Setup

- **Config**: `src/payload.config.ts` — SQLite adapter, Lexical editor, 3 collections (users, pages, media).
- **API route**: `src/app/api/[...slug]/route.ts` — Auto-generated, do not edit.
- **Admin layout**: `src/app/(payload)/admin/[[...segments]]/layout.tsx` — Auto-generated, imports `@payloadcms/next/css` for admin styles.
- **importMap**: `src/app/(payload)/admin/importMap.ts` — Maps Payload component paths to imports. `RenderServerComponent` must be imported from `@payloadcms/ui/elements/RenderServerComponent` (not `@payloadcms/ui` directly).

### Styling

- **Tailwind CSS 4** via `@tailwindcss/postcss` (no `tailwind.config.*` file needed).
- **shadcn/ui** components in `src/components/ui/` — uses `@base-ui/react` (NOT Radix). Button does NOT support `asChild` prop; use `buttonVariants()` + `Link` pattern instead.
- **Payload admin styles**: Loaded via `import '@payloadcms/next/css'` in the admin layout. Do NOT use SCSS imports for Payload styles.
- **CSS files**: `src/app/globals.css` and `src/app/(frontend)/globals.css` (both needed — root and frontend layout respectively).

### Key Gotchas

- **pnpm strict mode**: `@payloadcms/ui` must be listed as a direct dependency, otherwise it's not resolvable from project code.
- **Payload CLI commands fail with ESM error**: `payload generate:types`, `payload generate:importmap` etc. crash with `ERR_REQUIRE_ASYNC_MODULE` on Node 20/22. Type generation and importMap generation must be done manually or via custom scripts.
- **Schema changes**: Adding required columns to existing tables triggers a confirmation prompt. Use `PAYLOAD_DROP_DATABASE=true` env var to reset during development.
- **Media uploads**: `staticDir: 'media'` stores files at project root `/media/`. Access control is open (read/create/update all return `true`).

### Path Aliases

- `@/*` → `./src/*`
- `@payload-config` → `./src/payload.config.ts`

### Docker

- `Dockerfile` uses `node:22-alpine` + pnpm.
- `pnpm-workspace.yaml` needs `packages: ['.']` temporarily during `pnpm install` in build context.
- Volumes: `sqlite-data:/app/data` and `media-data:/app/media`.
- nginx config serves `/media/` directly from disk, `/api/media/file/` proxied to Next.js.

## AGENTS.md Notes

This is NOT the stock Next.js you may know. Next.js 16.2.9 has breaking changes — read `node_modules/next/dist/docs/` before writing unfamiliar Next.js code.
