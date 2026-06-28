# Stage 1: Install dependencies
FROM node:22-alpine AS dependencies
RUN echo "▸ Stage 1: Installing dependencies..." && \
    corepack enable && corepack prepare pnpm@9.15.9 --activate

WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    echo "▸ Running pnpm install..." && pnpm install --frozen-lockfile

# Stage 2: Build Next.js
FROM node:22-alpine AS builder
RUN echo "▸ Stage 2: Building Next.js..." && \
    corepack enable && corepack prepare pnpm@9.15.9 --activate

WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .

ARG NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
ENV NODE_ENV=production
ENV IS_DOCKER_BUILD=true
RUN --mount=type=cache,target=/app/.next/cache \
    echo "▸ Running pnpm build..." && pnpm build

# Stage 3: Production runner
FROM node:22-alpine AS runner
RUN echo "▸ Stage 3: Setting up production runner..."

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
RUN mkdir .next && chown nextjs:nodejs .next

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

RUN echo "✓ Build complete: standalone + static assets ready"

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
