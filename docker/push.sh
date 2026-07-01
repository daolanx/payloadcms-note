#!/bin/bash
# Push the most recently built image to ACR
# Usage: ./docker/push.sh [tag]
#   No argument: pushes the latest local image
#   With argument: pushes the specified tag

set -euo pipefail

# Load .env.local if exists (for local dev)
if [ -f .env.local ]; then
  set -a
  . .env.local
  set +a
fi

REPO="$ACR_REGISTRY/$ACR_NAMESPACE/$IMAGE_NAME"

if [ -n "${1:-}" ]; then
  TAG="$1"
else
  TAG=$(docker images --format '{{.Tag}}' "$REPO" | head -1)
fi

if [ -z "$TAG" ]; then
  echo "✗ No image found for $REPO"
  exit 1
fi

IMAGE="$REPO:$TAG"
echo "▸ Pushing $IMAGE ..."
docker push "$IMAGE"
echo "✓ Pushed $IMAGE"
