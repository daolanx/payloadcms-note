#!/bin/bash
# One-time ECS initialization: upload deploy script, env file, create directories
# Usage: bash init-ecs.sh
# Requires ECS_HOST in .env.local

set -euo pipefail

# ============ Load env ============
if [ ! -f .env.local ]; then
  echo "✗ .env.local not found"
  exit 1
fi
source .env.local

if [ -z "${ECS_HOST:-}" ]; then
  echo "✗ ECS_HOST not set in .env.local"
  exit 1
fi

# ============ Config ============
REMOTE_DIR="/opt/notes"

# ============ 1. Create remote directory ============
echo "▸ [1/3] Create remote directory ..."
ssh root@$ECS_HOST "mkdir -p $REMOTE_DIR/db"

# ============ 2. Upload deploy script ============
echo "▸ [2/3] Upload deploy script ..."
scp "$(dirname "$0")/deploy.sh" root@$ECS_HOST:$REMOTE_DIR/deploy.sh
ssh root@$ECS_HOST "chmod +x $REMOTE_DIR/deploy.sh"

# ============ 3. Upload .env.local ============
echo "▸ [3/3] Upload .env.local ..."
scp .env.local root@$ECS_HOST:$REMOTE_DIR/.env.local

echo ""
echo "✓ ECS initialized at $ECS_HOST"
echo ""
echo "Next: SSH into ECS and run:"
echo "  bash $REMOTE_DIR/deploy.sh --tag <image_tag>"
