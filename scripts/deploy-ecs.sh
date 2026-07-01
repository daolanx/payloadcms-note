#!/bin/bash
# Full ECS deployment: login ACR, upload env, create dirs, create container
# Usage: bash deploy-ecs.sh <ecs_ip> [image_tag]
#   Example: bash deploy-ecs.sh 218.244.153.47 v1.2.4

set -euo pipefail

# ============ Args ============
ECS_IP="${1:?Usage: bash deploy-ecs.sh <ecs_ip> [image_tag]}"
TAG="${2:-latest}"

# ============ Config ============
ACR_REGISTRY="crpi-l5xg3bxsmy58r36i.cn-hangzhou.personal.cr.aliyuncs.com"
ACR_NAMESPACE="daolanx"
ACR_USERNAME="daolanx"
IMAGE_NAME="payload-notes"
IMAGE="$ACR_REGISTRY/$ACR_NAMESPACE/$IMAGE_NAME:$TAG"
CONTAINER="my-notes"

# ============ 1. Login ACR on ECS ============
echo "▸ [1/4] Login to ACR on ECS ..."
ssh root@$ECS_IP "echo '$ACR_PASSWORD' | docker login $ACR_REGISTRY -u $ACR_USERNAME --password-stdin" 2>/dev/null

# ============ 2. Upload .env.local ============
echo "▸ [2/4] Upload .env.local ..."
scp .env.local root@$ECS_IP:/opt/notes/.env.local

# ============ 3. Create data directory ============
echo "▸ [3/4] Create data directory ..."
ssh root@$ECS_IP "mkdir -p /opt/notes/db"

# ============ 4. Pull image and create container ============
echo "▸ [4/4] Pull image and create container ..."
ssh root@$ECS_IP "
  docker pull $IMAGE && \
  docker stop $CONTAINER 2>/dev/null || true && \
  docker rm $CONTAINER 2>/dev/null || true && \
  docker create \
    --name $CONTAINER \
    --restart always \
    -p 127.0.0.1:3000:3000 \
    -v /opt/notes/db:/app/db \
    --env-file /opt/notes/.env.local \
    $IMAGE && \
  docker start $CONTAINER
"

echo "✓ Deployed $IMAGE to $ECS_IP"
