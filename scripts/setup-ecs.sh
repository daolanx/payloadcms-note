#!/bin/bash
# First-time ECS setup:
# 1. SSH into ECS → install Docker + Docker Compose
# 2. Create deploy directory on ECS
# 3. Upload docker-compose.yml, nginx.conf, .env.local
# 4. Upload SSL certs if certs/cert.pem and certs/key.pem exist
set -e

cd "$(dirname "$0")/.."

# Load env vars from .env.local
if [ -f .env.local ]; then
  set -a
  source .env.local
  set +a
fi

echo "▸ Setting up ECS: ${ECS_HOST}"

# Install Docker on ECS
ssh "${ECS_USERNAME}@${ECS_HOST}" << EOF
  if ! command -v docker &> /dev/null; then
    echo "▸ Installing Docker..."
    yum install -y docker
    systemctl enable docker && systemctl start docker
  fi

  if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "▸ Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi

  mkdir -p ${DEPLOY_PATH}/certs
EOF

# Upload config files
echo "▸ Uploading config files..."
scp docker-compose.yml nginx.conf "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"
scp .env.local "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"

# Upload SSL certs if they exist locally
echo "▸ Checking SSL certs: certs/cert.pem certs/key.pem"
if [ -f certs/cert.pem ] && [ -f certs/key.pem ]; then
  echo "▸ Uploading SSL certs..."
  scp certs/cert.pem certs/key.pem "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/certs/"
else
  echo "⊘ SSL certs not found, skipping"
fi

echo "✓ ECS setup complete: ${ECS_HOST}"
