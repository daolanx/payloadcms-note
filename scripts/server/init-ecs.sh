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
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"

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

# ---- Step 1: Docker ------------------------------------------------
echo ""
echo "▸ [1/4] Checking Docker..."

if command -v docker &>/dev/null; then
  echo "  → Docker already installed: $(docker --version)"
else
  echo "  → Installing Docker..."
  yum install -y yum-utils
  # 优先使用阿里云镜像源（国内 ECS 速度快）
  yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 2>/dev/null \
    || yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io
  echo "  → Docker installed: $(docker --version)"
fi

systemctl enable docker
systemctl start docker
echo "  → Docker service enabled and started"

# ---- Step 2: Docker Compose ----------------------------------------
echo ""
echo "▸ [2/4] Checking Docker Compose..."

if docker compose version &>/dev/null; then
  echo "  → Docker Compose plugin already installed: $(docker compose version)"
elif command -v docker-compose &>/dev/null; then
  echo "  → docker-compose already installed: $(docker-compose --version)"
else
  echo "  → Installing Docker Compose plugin..."

  # 优先 yum 安装（国内 ECS 最快，无需访问 GitHub）
  if yum install -y docker-compose-plugin 2>/dev/null; then
    echo "  → Docker Compose plugin installed via yum"
  else
    # 兜底：直接下载二进制
    echo "  → Falling back to binary download..."
    COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
    curl -fSL "$COMPOSE_URL" -o /usr/local/bin/docker-compose || {
      echo "  ✗ Docker Compose install failed."
      echo "  → Please install manually: https://docs.docker.com/compose/install/"
      exit 1
    }
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "  → Docker Compose binary installed"
  fi
fi

# ---- Step 3: Auto-restart on reboot --------------------------------
echo ""
echo "▸ [3/4] Configuring auto-restart..."

systemctl enable docker 2>/dev/null || true
echo "  → Docker auto-restart enabled"

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
