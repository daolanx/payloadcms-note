#!/bin/bash
# Deploy to ECS: SSH into server, pull latest image, restart containers
# Usage: ./scripts/deploy.sh [tag]   (default: latest)
set -e

cd "$(dirname "$0")/.."

# Load env vars from .env.local
if [ -f .env.local ]; then
  set +a
  source .env.local
  set +a
fi

# Use VPC endpoint on ECS (faster, no public bandwidth)
# Inserts -vpc after instance ID: crpi-xxx.cn-hangzhou... → crpi-xxx-vpc.cn-hangzhou...
ACR_REGISTRY="${ACR_REGISTRY/.cn-hangzhou./-vpc.cn-hangzhou.}"

IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Deploying to ECS: ${ECS_HOST}"
echo "  Image: ${FULL_IMAGE}"

# Copy production compose file and nginx config to server
scp -o StrictHostKeyChecking=no compose.prod.yaml "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/compose.yaml"
scp -o StrictHostKeyChecking=no nginx.conf "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/nginx.conf"

# SSH into ECS and deploy
ssh -o StrictHostKeyChecking=no "${ECS_USERNAME}@${ECS_HOST}" << EOF
  cd ${DEPLOY_PATH}

  # Login to ACR for both podman and docker
  echo "${ACR_PASSWORD}" | podman login --username="${ACR_USERNAME}" --password-stdin "${ACR_REGISTRY}"
  echo "${ACR_PASSWORD}" | docker login --username="${ACR_USERNAME}" --password-stdin "${ACR_REGISTRY}"

  # Fix docker config
  printf '%s:%s' "${ACR_USERNAME}" "${ACR_PASSWORD}" | base64 > /tmp/auth_token.txt
  AUTH_TOKEN=\$(cat /tmp/auth_token.txt)
  printf '{"auths":{"%s":{"auth":"%s"}}}' "${ACR_REGISTRY}" "\$AUTH_TOKEN" > /root/.docker/config.json

  # Update image tag in compose.yaml (only app service, not nginx)
  sed -i '/app:/,/nginx:/{/image:/{s|image:.*|image: '"${FULL_IMAGE}"'|}}' compose.yaml

  # Pull and restart
  docker-compose --profile prod pull
  docker-compose --profile prod up -d --remove-orphans
EOF

echo "Deployed to ${ECS_HOST}"
