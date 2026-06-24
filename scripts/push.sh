#!/bin/bash
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

echo "▸ Logging in to ACR..."
docker login --username="${ACR_USERNAME}" "${ACR_REGISTRY}"

echo "▸ Pushing: ${FULL_IMAGE}"
docker push "${FULL_IMAGE}"

echo "✓ Done"
