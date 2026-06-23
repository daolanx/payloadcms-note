#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "▸ Building project..."
NODE_ENV=production pnpm build

echo "▸ Copying static assets..."
cp -r public .next/standalone/public
cp -r .next/static .next/standalone/.next/static

echo "✓ Standalone build ready at .next/standalone/"
