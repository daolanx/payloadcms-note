#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "▸ Building project..."
NODE_ENV=production pnpm build

echo "▸ Copying static assets..."
cp -r public .next/standalone/public
cp -r .next/static .next/standalone/.next/static

echo "▸ Packaging deployment bundle..."
cd .next/standalone
zip -rq -y ../../payload-cms-deploy.zip .
cd ../..

echo "✓ Deployment package created: payload-cms-deploy.zip ($(du -h payload-cms-deploy.zip | cut -f1))"
