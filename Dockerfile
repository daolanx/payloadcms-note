# === 阶段 1：构建应用 ===
FROM node:22-alpine AS builder
RUN corepack enable pnpm
WORKDIR /app

# 利用缓存：先装依赖
COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./
RUN pnpm install --frozen-lockfile

# 复制源码并编译
COPY . .
ENV NODE_ENV=production
RUN pnpm build

# === 阶段 2：运行应用 ===
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# 安装必要工具
RUN apk add --no-cache sqlite

# 复制 Next.js Standalone 产物及启动脚本
COPY --from=builder /app/public ./public
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --chown=node:node init-db.sql docker-entrypoint.sh ./

# 创建数据目录、改权限、加执行权限一步到位
RUN mkdir -p data media && \
    chown -R node:node data media && \
    chmod +x docker-entrypoint.sh

# 使用 Alpine 自带的非 root 用户
USER node

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["./docker-entrypoint.sh"]
