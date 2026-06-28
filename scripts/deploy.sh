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
# Inserts -vpc after instance ID: crpi-xxx.cn-hangzhou... → crpi-xxx-vpc.cn-hangzhou...
ACR_REGISTRY="${ACR_REGISTRY/.cn-hangzhou./-vpc.cn-hangzhou.}"

IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Deploying to ECS: ${ECS_HOST}"
echo "  Image: ${FULL_IMAGE}"

# Copy compose file to server
scp -o StrictHostKeyChecking=no "${COMPOSE_FILE}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"

# Copy nginx config (HTTPS if certs exist, HTTP otherwise)
if [ -f "${CERT_DIR}/cert.pem" ] && [ -f "${CERT_DIR}/key.pem" ]; then
  scp -o StrictHostKeyChecking=no "${NGINX_HTTPS}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/nginx.conf"
else
  scp -o StrictHostKeyChecking=no "${NGINX_HTTP}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/nginx.conf"
fi

# SSH into ECS and deploy
ssh -o StrictHostKeyChecking=no "${ECS_USERNAME}@${ECS_HOST}" << EOF
  set -e

  cd ${DEPLOY_PATH}

  # Login to ACR
  echo "${ACR_PASSWORD}" | docker login --username="${ACR_USERNAME}" --password-stdin "${ACR_REGISTRY}"

  # Export image tag for docker compose
  export APP_IMAGE="${FULL_IMAGE}"

  # Pull and restart
  docker compose pull
  docker compose up -d --remove-orphans

  # Clean up old images to free disk space
  docker image prune -f
EOF

echo "Deployed to ${ECS_HOST}"
