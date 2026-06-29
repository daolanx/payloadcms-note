#!/bin/bash
# Build production Docker image (linux/amd64) from local Dockerfile.
#
# Usage: ./scripts/build.sh [tag]   (default: latest)
# Reads ACR_REGISTRY, ACR_NAMESPACE, IMAGE_NAME from .env.local
# Passes NEXT_PUBLIC_SITE_URL as a build arg.
set -e

cd "$(dirname "$0")/.."

# Load env vars from .env.local
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi

# Ensure required env vars exist
for var in ACR_REGISTRY ACR_NAMESPACE IMAGE_NAME; do
  if [ -z "${!var}" ]; then
    echo "Error: $var is not set"
    exit 1
  fi
done

IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "▸ Building Docker image: ${FULL_IMAGE}"
docker build -f docker/production/Dockerfile --platform linux/amd64 \
  --build-arg NEXT_PUBLIC_SITE_URL="${NEXT_PUBLIC_SITE_URL}" \
  -t "${FULL_IMAGE}" .

echo "✓ Done: ${FULL_IMAGE}"
