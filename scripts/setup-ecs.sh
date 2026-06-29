#!/bin/bash
# First-time ECS setup:
# 1. SSH into ECS → install Docker + Docker Compose
# 2. Create deploy directory on ECS
# 3. Upload docker/production/ and .env.local
#
# Usage: ./scripts/setup-ecs.sh
# Reads ACR and ECS config from .env.local.
set -e

cd "$(dirname "$0")/.."

# Load env vars from .env.local
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi

# Config files
PROD_DIR="docker/production"
ENV_FILE=".env.local"

echo "▸ Setting up ECS: ${ECS_HOST}"

# Install Docker on ECS
echo "▸ Step 1: Checking Docker installation..."
ssh "${ECS_USERNAME}@${ECS_HOST}" << EOF
  set -e

  if ! command -v docker &> /dev/null; then
    echo "  → Installing Docker..."
    yum install -y docker
    systemctl enable docker && systemctl start docker
    echo "  → Docker installed"
  else
    echo "  → Docker already installed"
  fi

  if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "  → Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "  → Docker Compose installed"
  else
    echo "  → Docker Compose already installed"
  fi

  mkdir -p ${DEPLOY_PATH}/docker/production
  echo "  → Deploy directory ready"
EOF

# Upload production directory and env file
echo "▸ Step 2: Uploading config files..."
scp -r "${PROD_DIR}/" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/docker/production/"
echo "  → ${PROD_DIR}/ uploaded"
scp "${ENV_FILE}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"
echo "  → ${ENV_FILE} uploaded"

echo "✓ ECS setup complete: ${ECS_HOST}"
