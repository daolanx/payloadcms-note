#!/bin/bash
# ============================================================
# ECS Initialization Script
# ============================================================
# Runs ON the ECS to install Docker, Docker Compose, and
# verify the deploy directory structure.
#
# This script is uploaded by setup-ecs.sh and executed via SSH,
# but can also be run manually on ECS:
#   bash ~/deploy/scripts/server/init-ecs.sh
# ============================================================
set -e

# Resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Load .env.local if present (for ACR_*, NEXT_PUBLIC_SITE_URL, etc.)
if [ -f "$DEPLOY_DIR/.env.local" ]; then
  set -a
  source "$DEPLOY_DIR/.env.local"
  set +a
fi

echo "============================================"
echo "  ECS Initialization"
echo "  Host: $(hostname)"
echo "  Deploy: $DEPLOY_DIR"
echo "============================================"

# ---- Step 1: Docker / Podman ----------------------------------------
echo ""
echo "▸ [1/4] Checking Docker..."

# Detect runtime: podman or docker
RUNTIME=""
if command -v podman &>/dev/null; then
  RUNTIME="podman"
  echo "  → Podman already installed: $(podman --version)"
elif command -v docker &>/dev/null; then
  RUNTIME="docker"
  echo "  → Docker already installed: $(docker --version)"
else
  echo "  → Installing Docker..."
  yum install -y yum-utils
  yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 2>/dev/null \
    || yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io
  RUNTIME="docker"
  echo "  → Docker installed: $(docker --version)"
fi

# Enable service (podman or docker)
if [ "$RUNTIME" = "podman" ]; then
  systemctl enable podman 2>/dev/null || systemctl enable podman-restart.service 2>/dev/null || true
else
  systemctl enable docker
  systemctl start docker
fi
echo "  → $RUNTIME service enabled"

# ---- Step 2: Docker Compose ----------------------------------------
echo ""
echo "▸ [2/4] Checking Docker Compose..."

# Determine compose command based on runtime
if [ "$RUNTIME" = "podman" ]; then
  COMPOSE_CMD="podman-compose"
  if command -v podman-compose &>/dev/null; then
    echo "  → podman-compose already installed: $(podman-compose --version)"
  else
    echo "  → Installing podman-compose..."
    pip3 install podman-compose 2>/dev/null \
      || pip install podman-compose 2>/dev/null \
      || { echo "  ✗ podman-compose install failed"; exit 1; }
    echo "  → podman-compose installed"
  fi
else
  COMPOSE_CMD="docker compose"
  if docker compose version &>/dev/null; then
    echo "  → Docker Compose plugin already installed: $(docker compose version)"
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
    echo "  → docker-compose already installed: $(docker-compose --version)"
  else
    echo "  → Installing Docker Compose plugin..."
    if yum install -y docker-compose-plugin 2>/dev/null; then
      echo "  → Docker Compose plugin installed via yum"
    else
      echo "  → Falling back to binary download..."
      COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
      curl -fSL "$COMPOSE_URL" -o /usr/local/bin/docker-compose || {
        echo "  ✗ Docker Compose install failed."
        exit 1
      }
      chmod +x /usr/local/bin/docker-compose
      ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
      COMPOSE_CMD="docker-compose"
      echo "  → Docker Compose binary installed"
    fi
  fi
fi

# ---- Step 3: Auto-restart on reboot (already done in Step 1) --------
echo ""
echo "▸ [3/4] Auto-restart already configured"

# ---- Step 4: Verify deploy structure --------------------------------
echo ""
echo "▸ [4/4] Verifying deploy directory..."

mkdir -p "$DEPLOY_DIR/docker/production"

if [ -d "$DEPLOY_DIR/docker/production" ]; then
  FILE_COUNT=$(find "$DEPLOY_DIR/docker/production" -type f | wc -l)
  echo "  → docker/production/ contains $FILE_COUNT file(s)"
  if [ "$FILE_COUNT" -gt 0 ]; then
    ls -1 "$DEPLOY_DIR/docker/production/"
  fi
else
  echo "  ⚠ docker/production/ not found"
fi

if [ -f "$DEPLOY_DIR/.env.local" ]; then
  echo "  → .env.local present"
else
  echo "  ⚠ .env.local not found — services may fail to start"
fi

echo ""
echo "============================================"
echo "  ✓ ECS initialization complete"
echo "============================================"
