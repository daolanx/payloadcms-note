#!/bin/bash
# Push Docker image to Alibaba Cloud Container Registry (ACR).
#
# Usage: ./scripts/push.sh [tag]   (default: latest)
# Reads ACR_REGISTRY, ACR_USERNAME, ACR_PASSWORD, ACR_NAMESPACE, IMAGE_NAME from .env.local
set -e

cd "$(dirname "$0")/.."

# Load env vars from .env.local
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi

# Ensure required env vars exist
for var in ACR_REGISTRY ACR_USERNAME ACR_PASSWORD IMAGE_NAME; do
  if [ -z "${!var}" ]; then
    echo "Error: $var is not set"
    exit 1
  fi
done

IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "▸ Logging in to ACR..."
echo "${ACR_PASSWORD}" | docker login --username="${ACR_USERNAME}" --password-stdin "${ACR_REGISTRY}"

echo "▸ Pushing: ${FULL_IMAGE}"
docker push "${FULL_IMAGE}"

echo "✓ Done: ${FULL_IMAGE}"
