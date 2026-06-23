#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "▸ 构建项目..."
NODE_ENV=production pnpm build

echo "▸ 复制静态资源..."
cp -r public .next/standalone/public
cp -r .next/static .next/standalone/.next/static

echo "▸ 打包部署包..."
cd .next/standalone
zip -rq -y ../../payload-cms-deploy.zip .
cd ../..

echo "✓ 部署包已生成: payload-cms-deploy.zip ($(du -h payload-cms-deploy.zip | cut -f1))"
