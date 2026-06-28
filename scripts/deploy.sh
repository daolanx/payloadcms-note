#!/bin/bash
# Deploy to ECS: SSH into server, pull latest image, restart containers
# Usage: ./scripts/deploy.sh [tag]   (default: latest)
set -e

cd "$(dirname "$0")/.."

# Load env vars from .env.local
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi

# Ensure required env vars exist
for var in ACR_REGISTRY ACR_NAMESPACE ACR_USERNAME ACR_PASSWORD IMAGE_NAME ECS_HOST ECS_USERNAME DEPLOY_PATH; do
  if [ -z "${!var}" ]; then
    echo "Error: $var is not set in .env.local"
    exit 1
  fi
done

# Config files
COMPOSE_FILE="compose.yaml"
NGINX_HTTP="nginx.conf"
NGINX_HTTPS="nginx-https.conf"
ENV_FILE=".env.local"
CERT_DIR="certs"

# Use VPC endpoint on ECS (faster, no public bandwidth)
ACR_REGISTRY="${ACR_REGISTRY/.cn-hangzhou./-vpc.cn-hangzhou.}"

IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "▸ Deploying to ECS: ${ECS_HOST}"
echo "  Image: ${FULL_IMAGE}"

# Copy compose file to server
echo "▸ Uploading ${COMPOSE_FILE}..."
scp -o StrictHostKeyChecking=no "${COMPOSE_FILE}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"

# Copy nginx config (HTTPS if certs exist, HTTP otherwise)
if [ -f "${CERT_DIR}/cert.pem" ] && [ -f "${CERT_DIR}/key.pem" ]; then
  echo "▸ SSL certs found, uploading HTTPS config..."
  scp -o StrictHostKeyChecking=no "${NGINX_HTTPS}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/nginx.conf"
else
  echo "▸ No SSL certs, uploading HTTP config..."
  scp -o StrictHostKeyChecking=no "${NGINX_HTTP}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/nginx.conf"
fi

# Upload 502 maintenance page
echo "▸ Uploading 502.html..."
ssh -o StrictHostKeyChecking=no "${ECS_USERNAME}@${ECS_HOST}" "mkdir -p ${DEPLOY_PATH}/nginx"
scp -o StrictHostKeyChecking=no "nginx/502.html" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/nginx/502.html"

# SSH into ECS and deploy
echo "▸ Connecting to ECS..."
ssh -o StrictHostKeyChecking=no "${ECS_USERNAME}@${ECS_HOST}" << EOF
  set -e

  cd ${DEPLOY_PATH}

  # Login to ACR
  echo "▸ Logging in to ACR..."
  echo "${ACR_PASSWORD}" | docker login --username="${ACR_USERNAME}" --password-stdin "${ACR_REGISTRY}"

  # Record current image for rollback
  PREV_IMAGE=\$(docker compose ps -q | head -1 | xargs docker inspect --format='{{.Config.Image}}' 2>/dev/null || echo "none")
  echo "Previous image: \$PREV_IMAGE"

  # Export image tag for docker compose
  export APP_IMAGE="${FULL_IMAGE}"
  echo "Deploying: \$APP_IMAGE"

  # Pull and restart
  echo "▸ Pulling image..."
  docker compose pull
  echo "▸ Starting containers..."
  docker compose up -d --remove-orphans

  # Health check with rollback on failure
  echo "▸ Checking health..."
  for i in \$(seq 1 12); do
    UNHEALTHY=\$(docker compose ps | grep -cE "Exit|Restarting" || true)
    if [ "\$UNHEALTHY" -eq 0 ]; then
      echo "✓ All containers running"
      break
    fi
    if [ "\$i" -eq 12 ]; then
      echo "✗ Deployment failed — rolling back to \$PREV_IMAGE"
      if [ "\$PREV_IMAGE" != "none" ]; then
        export APP_IMAGE="\$PREV_IMAGE"
        docker compose up -d --remove-orphans
      fi
      docker compose logs --tail=100
      exit 1
    fi
    echo "  Waiting... (\$i/12)"
    sleep 5
  done

  # Clean up old images (only recent 72h)
  echo "▸ Cleaning up old images..."
  docker image prune -f --filter "until=72h"
EOF

echo "✓ Deployed to ${ECS_HOST}"
