#!/bin/bash
# Create/recreate the notes-app container on ECS
# Usage: bash create-container.sh [image_tag]
#   Default tag: latest

set -euo pipefail

TAG="${1:-latest}"
IMAGE="crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com/daolanx/payload-notes:$TAG"
CONTAINER="my-notes"

# Stop and remove existing container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "▸ Stopping existing container..."
  docker stop "$CONTAINER" 2>/dev/null || true
  docker rm "$CONTAINER" 2>/dev/null || true
fi

# Create container
echo "▸ Creating $CONTAINER from $IMAGE ..."
docker create \
  --name "$CONTAINER" \
  --restart always \
  -p 127.0.0.1:3000:3000 \
  -v /opt/notes/db:/app/db \
  --env-file /opt/notes/.env.local \
  "$IMAGE"

# Start
docker start "$CONTAINER"
echo "✓ $CONTAINER started"
