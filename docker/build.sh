#!/bin/bash
# Build Docker image for payload-notes
# Usage: ./docker/build.sh [-t|--tag <tag>]
#   Without -t/--tag: default "commitHash-timestamp"

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

load_env
TAG=$(parse_tag "$@")

TAG="${TAG:-$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)}"
IMAGE="$ACR_REGISTRY/$ACR_NAMESPACE/$IMAGE_NAME:$TAG"

echo "▸ Building $IMAGE (linux/amd64) ..."
docker build --platform linux/amd64 -f docker/Dockerfile -t "$IMAGE" .
echo "✓ Built $IMAGE"
