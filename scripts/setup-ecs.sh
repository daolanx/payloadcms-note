#!/bin/bash
# First-time ECS setup:
# 1. SSH into ECS → install Docker + Docker Compose
# 2. Create deploy directory on ECS
# 3. Upload compose.yaml, nginx.conf, .env.local
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

  # Install Portainer (container management UI)
  if ! docker ps -a --format '{{.Names}}' | grep -q portainer; then
    echo "▸ Installing Portainer from ACR..."
    # Login to ACR for pulling images
    echo "${ACR_PASSWORD}" | docker login --username="${ACR_USERNAME}" --password-stdin "${ACR_REGISTRY}"
    docker volume create portainer_data
    docker run -d \
      --name portainer \
      --restart=always \
      -p 9000:9000 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      ${ACR_REGISTRY}/${ACR_NAMESPACE}/portainer:latest
  fi

  mkdir -p ${DEPLOY_PATH}/certs
EOF

# Upload config files
echo "▸ Uploading config files..."
scp compose.yaml "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"
scp .env.local "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"

# Check SSL certs and enable HTTPS if present
echo "▸ Checking SSL certs: certs/cert.pem certs/key.pem"
if [ -f certs/cert.pem ] && [ -f certs/key.pem ]; then
  echo "▸ SSL certs found, using HTTPS config..."
  scp certs/cert.pem certs/key.pem "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/certs/"
  scp nginx-ssl.conf "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/nginx.conf"
  echo "✓ HTTPS enabled"
else
  echo "⊘ SSL certs not found, using HTTP-only config"
  scp nginx.conf "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"
fi

echo "✓ ECS setup complete: ${ECS_HOST}"
