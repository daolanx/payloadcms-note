#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Load env vars from .env.local
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi

IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "▸ Deploying to ECS: ${ECS_HOST}"
echo "  Image: ${FULL_IMAGE}"

# SSH into ECS and deploy
ssh "${ECS_USERNAME}@${ECS_HOST}" << EOF
  cd ${DEPLOY_PATH}

  # Login to ACR
  docker login --username="${ACR_USERNAME}" "${ACR_REGISTRY}"

  # Update image tag in docker-compose.yml
  sed -i "s|image:.*|image: ${FULL_IMAGE}|" docker-compose.yml

  # Pull and restart
  docker compose pull
  docker compose up -d --remove-orphans
EOF

echo "✓ Deployed to ${ECS_HOST}"
