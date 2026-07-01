#!/bin/bash
# Build Docker image for payload-notes
# Usage: ./docker/build.sh [tag]
#   TAG env var or argument overrides default "commitHash-timestamp"

set -euo pipefail

# Load .env.local if exists (for local dev)
if [ -f .env.local ]; then
  set -a
  . .env.local
  set +a
fi

TAG="${1:-${TAG:-$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)}}"
IMAGE="$ACR_REGISTRY/$ACR_NAMESPACE/$IMAGE_NAME:$TAG"

echo "▸ Building $IMAGE (linux/amd64) ..."
docker build --platform linux/amd64 -f docker/Dockerfile -t "$IMAGE" .
echo "✓ Built $IMAGE"
