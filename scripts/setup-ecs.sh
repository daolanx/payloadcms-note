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

# Config files
COMPOSE_FILE="compose.yaml"
NGINX_HTTP="nginx.conf"
NGINX_HTTPS="nginx-https.conf"
ENV_FILE=".env.local"
CERT_DIR="certs"

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

  # Install Portainer (container management UI)
  if ! docker ps -a --format '{{.Names}}' | grep -q portainer; then
    echo "  → Installing Portainer from ACR..."
    echo "${ACR_PASSWORD}" | docker login --username="${ACR_USERNAME}" --password-stdin "${ACR_REGISTRY}"
    docker volume create portainer_data
    docker run -d \
      --name portainer \
      --restart=always \
      -p 9000:9000 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      ${ACR_REGISTRY}/${ACR_NAMESPACE}/portainer:latest
    echo "  → Portainer installed"
  else
    echo "  → Portainer already installed"
  fi

  mkdir -p ${DEPLOY_PATH}/certs
  echo "  → Deploy directory ready"
EOF

# Upload config files
echo "▸ Step 2: Uploading config files..."
scp "${COMPOSE_FILE}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"
echo "  → ${COMPOSE_FILE} uploaded"
scp "${ENV_FILE}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"
echo "  → ${ENV_FILE} uploaded"

# Check SSL certs and enable HTTPS if present
echo "▸ Step 3: Checking SSL certs..."
if [ -f "${CERT_DIR}/cert.pem" ] && [ -f "${CERT_DIR}/key.pem" ]; then
  echo "  → SSL certs found, uploading..."
  scp "${CERT_DIR}/cert.pem" "${CERT_DIR}/key.pem" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/certs/"
  scp "${NGINX_HTTPS}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/nginx.conf"
  echo "  → HTTPS config uploaded"
else
  echo "  → No SSL certs, using HTTP config"
  scp "${NGINX_HTTP}" "${ECS_USERNAME}@${ECS_HOST}:${DEPLOY_PATH}/"
fi

echo "✓ ECS setup complete: ${ECS_HOST}"
