#!/bin/bash
# Remote deployment script — executed on ECS via SSH during CI/CD.
# Not called directly; invoked by .github/workflows/deploy.yml.
#
# Required env vars:
#   ACR_VPC_REGISTRY  — VPC registry endpoint (faster pull on ECS)
#   ACR_NAMESPACE      — ACR namespace
#   ACR_USERNAME       — ACR username
#   ACR_PASSWORD       — ACR password
#   IMAGE_NAME         — container image name
#   IMAGE_TAG          — tag to deploy (short SHA)
#   DEPLOY_PATH        — deploy directory on ECS
set -euo pipefail

# ─── Config ─────────────────────────────────────────────────────────
APP_CONTAINER="notes-app"

# Detect compose command (podman-compose vs docker compose)
# Verify the command actually works before selecting it
COMPOSE=""
if command -v podman-compose &>/dev/null; then
  if podman-compose version &>/dev/null 2>&1; then
    COMPOSE="podman-compose"
  fi
fi
if [ -z "$COMPOSE" ] && docker compose version &>/dev/null 2>&1; then
  COMPOSE="docker compose"
fi
if [ -z "$COMPOSE" ] && command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
fi
if [ -z "$COMPOSE" ]; then
  echo "::error::No compose tool found"
  exit 1
fi
echo "  Using: $COMPOSE"

# ─── 0. Validate required env vars ──────────────────────────────────
REQUIRED_VARS="ACR_VPC_REGISTRY ACR_NAMESPACE ACR_USERNAME ACR_PASSWORD IMAGE_NAME IMAGE_TAG DEPLOY_PATH"
for var in $REQUIRED_VARS; do
  if [ -z "${!var:-}" ]; then
    echo "::error::Required env var $var is not set"
    exit 1
  fi
done

# ─── 1. Login to ACR (VPC endpoint) ────────────────────────────────
echo "▸ Logging in to ACR..."
echo "$ACR_PASSWORD" | docker login "$ACR_VPC_REGISTRY" \
  -u "$ACR_USERNAME" \
  --password-stdin

cd "$DEPLOY_PATH/docker/production"

# ─── 2. Record current image for rollback ───────────────────────────
PREV_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$APP_CONTAINER" 2>/dev/null || echo "none")
export APP_IMAGE="$ACR_VPC_REGISTRY/$ACR_NAMESPACE/$IMAGE_NAME:$IMAGE_TAG"

echo "  Previous: $PREV_IMAGE"
echo "  Deploying: $APP_IMAGE"

# ─── 3. Pull new image (old container still running) ────────────────
$COMPOSE pull app

# ─── 4. Verify image exists locally ─────────────────────────────────
docker image inspect "$APP_IMAGE" > /dev/null 2>&1 || {
  echo "::error::Image $APP_IMAGE not found locally after pull"
  exit 1
}

# ─── 5. Replace app container (nginx stays online) ──────────────────
$COMPOSE up -d --force-recreate --no-deps --remove-orphans app

# ─── 6. Health check ────────────────────────────────────────────────
HAS_HEALTH=$(docker inspect --format='{{if .State.Health}}true{{else}}false{{end}}' "$APP_CONTAINER" 2>/dev/null || echo "false")

if [ "$HAS_HEALTH" = "false" ]; then
  echo "::warning::No HEALTHCHECK defined — skipping health verification"
else
  for i in $(seq 1 20); do
    HEALTHY=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$APP_CONTAINER" 2>/dev/null || echo "missing")
    RUNNING=$(docker inspect --format='{{.State.Running}}' "$APP_CONTAINER" 2>/dev/null || echo "false")

    if [ "$HEALTHY" = "healthy" ] && [ "$RUNNING" = "true" ]; then
      echo "✓ App healthy"
      break
    fi

    # Container crashed — fail fast
    if [ "$HEALTHY" = "missing" ] || [ "$RUNNING" = "false" ]; then
      echo "::error::App not running (health=$HEALTHY, running=$RUNNING)"
      $COMPOSE logs --tail=50 app
      break
    fi

    # Last iteration — timeout
    if [ "$i" -eq 20 ]; then
      echo "::error::Health check timed out (health=$HEALTHY)"
      $COMPOSE logs --tail=100
      break
    fi

    echo "  Waiting... ($i/20, status=$HEALTHY)"
    sleep 5
  done
fi

# ─── 7. Rollback if unhealthy ───────────────────────────────────────
FINAL_HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$APP_CONTAINER" 2>/dev/null || echo "missing")
# If no HEALTHCHECK, assume healthy (skip already handled above)
[ "$HAS_HEALTH" = "false" ] && FINAL_HEALTH="healthy"

if [ "$FINAL_HEALTH" != "healthy" ]; then
  echo "::error::Deployment failed — rolling back"
  if [ "$PREV_IMAGE" != "none" ]; then
    export APP_IMAGE="$PREV_IMAGE"
    $COMPOSE up -d --force-recreate --no-deps --remove-orphans app

    # Verify rollback succeeded
    sleep 10
    ROLLBACK_HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$APP_CONTAINER" 2>/dev/null || echo "missing")
    ROLLBACK_RUNNING=$(docker inspect --format='{{.State.Running}}' "$APP_CONTAINER" 2>/dev/null || echo "false")

    if [ "$ROLLBACK_HEALTH" = "healthy" ] || [ "$ROLLBACK_HEALTH" = "none" ] && [ "$ROLLBACK_RUNNING" = "true" ]; then
      echo "✓ Rollback to $PREV_IMAGE succeeded"
    else
      echo "::error::Rollback failed! Manual intervention required"
      exit 2
    fi
  else
    echo "No previous image to rollback to"
  fi
  exit 1
fi

# ─── 8. Cleanup ─────────────────────────────────────────────────────
docker image prune -f --filter "until=72h" 2>/dev/null || true
echo "✓ Deployment successful"
