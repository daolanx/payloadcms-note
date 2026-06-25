#!/bin/bash
# Build Docker image from local Dockerfile
# Usage: ./scripts/build.sh [tag]   (default: latest)
set -e

cd "$(dirname "$0")/.."

# Load env vars from .env.local
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi

IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "▸ Building Docker image: ${FULL_IMAGE}"
docker build --platform linux/amd64 \
  --build-arg NEXT_PUBLIC_SITE_URL="${NEXT_PUBLIC_SITE_URL}" \
  -t "${FULL_IMAGE}" .

echo "✓ Done: ${FULL_IMAGE}"
