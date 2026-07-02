#!/bin/bash
# Push the most recently built image to ACR
# Usage: ./docker/push.sh [-t|--tag <tag>]
#   Without -t/--tag: pushes the latest local image
#   With -t/--tag: pushes the specified tag

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

load_env
TAG=$(parse_tag "$@")

REPO="$ACR_REGISTRY/$ACR_NAMESPACE/$IMAGE_NAME"

if [ -n "${TAG:-}" ]; then
  :
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
