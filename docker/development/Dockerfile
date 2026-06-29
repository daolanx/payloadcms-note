FROM node:22-alpine
RUN echo "▸ Setting up dev environment..." && \
    corepack enable && corepack prepare pnpm@9.15.9 --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    echo "▸ Installing dependencies..." && pnpm install --frozen-lockfile

COPY . .

ENV WATCHPACK_POLLING=true
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

RUN echo "✓ Dev environment ready"

EXPOSE 3000

CMD ["pnpm", "dev"]
