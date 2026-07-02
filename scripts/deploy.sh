#!/bin/bash
# Deploy container on ECS: pull image, recreate container
# Usage: bash deploy.sh [--tag <image_tag>]
#   Example: bash deploy.sh --tag v1.2.5

set -euo pipefail

# ============ Args ============
TAG="latest"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ============ Load env ============
REMOTE_DIR="/opt/notes"
if [ ! -f "$REMOTE_DIR/.env.local" ]; then
  echo "✗ $REMOTE_DIR/.env.local not found. Run init-ecs.sh first."
  exit 1
fi
source "$REMOTE_DIR/.env.local"

# ============ Config (from .env.local) ============
ACR_REGISTRY="${ACR_REGISTRY:?ACR_REGISTRY not set in .env.local}"
ACR_NAMESPACE="${ACR_NAMESPACE:?ACR_NAMESPACE not set in .env.local}"
ACR_USERNAME="${ACR_USERNAME:?ACR_USERNAME not set in .env.local}"
IMAGE_NAME="${IMAGE_NAME:-payload-notes}"
CONTAINER="${CONTAINER:-my-notes}"
IMAGE="$ACR_REGISTRY/$ACR_NAMESPACE/$IMAGE_NAME:$TAG"

# ============ 1. Login ACR ============
echo "▸ [1/3] Login to ACR ..."
echo "$ACR_PASSWORD" | docker login $ACR_REGISTRY -u $ACR_USERNAME --password-stdin 2>/dev/null

# ============ 2. Pull image ============
echo "▸ [2/3] Pull image: $IMAGE ..."
docker pull "$IMAGE"

# ============ 3. Recreate container ============
echo "▸ [3/3] Recreate container ..."
docker stop "$CONTAINER" 2>/dev/null || true
docker rm "$CONTAINER" 2>/dev/null || true
docker create \
  --name "$CONTAINER" \
  --restart always \
  -p 127.0.0.1:3000:3000 \
  -v "$REMOTE_DIR/db:/app/db" \
  --env-file "$REMOTE_DIR/.env.local" \
  "$IMAGE" && \
docker start "$CONTAINER"

echo ""
echo "✓ Deployed $IMAGE"
