# Pitfalls I Hit

Real-world issues encountered during development and deployment, with solutions.

## 1. Payload CMS Login Fails Silently

**Symptom**: Login returns HTTP 200 with valid token, but browser redirects back to `/admin/login`.

**Cause**: Payload CMS cookie auth requires `Origin` or `Sec-Fetch-Site` header. Chrome omits `Sec-Fetch-Site` for AJAX requests over HTTP.

**Fix**: Nginx origin injection (`proxy_set_header Origin "http://$host"`) or deploy with HTTPS — browsers send `Sec-Fetch-Site: same-origin` correctly over HTTPS.

## 2. Podman vs Docker Credential Separation

**Problem**: `podman login` succeeds but `docker-compose pull` fails with `denied`.

**Cause**: Podman and Docker have separate credential stores. `docker-compose` reads Docker's config, not Podman's.

**Fix**: Deploy script logs into both `podman login` and `docker login`, then generates a unified `config.json`.

## 3. Mac Build → ECS Deploy Architecture Mismatch

**Error**: `no image found in image index for architecture amd64`

**Cause**: Image built on Mac (arm64), ECS runs amd64.

**Fix**: Build script specifies `--platform linux/amd64` with QEMU emulation.

## 4. Next.js 16 Breaking Changes

Next.js 16.2.9 introduces breaking changes — layout nesting rules, `@payloadcms/next/css` import paths, and Turbopack config incompatibilities. Check `node_modules/next/dist/docs/` before upgrading.

## 5. Payload CMS CLI ESM Error

`payload generate:types` crashes with `ERR_REQUIRE_ASYNC_MODULE` on Node 20/22. Workaround: maintain type files manually or use custom scripts.

## 6. Payload CMS importMap RenderServerComponent Wrong Path

**Symptom**: `pnpm build` fails with `Type error: Module '"@payloadcms/ui"' has no exported member 'RenderServerComponent'`.

**Cause**: `generate-importmap.mjs` hardcodes `'@payloadcms/ui#RenderServerComponent'`, but `RenderServerComponent` is not re-exported from the package root. The actual path is `@payloadcms/ui/elements/RenderServerComponent`.

**Fix**: Update the script's `COMPONENTS` array to use the full subpath: `'@payloadcms/ui/elements/RenderServerComponent#RenderServerComponent'`.

## 7. Container Name Conflict During Deployment

**Symptom**: `docker compose up -d` fails with `the container name "notes-app" is already in use`.

**Cause**: Previous deployment's container still exists. `docker compose up -d --remove-orphans` does not remove containers that share the same name but belong to a different compose project.

**Fix**: Explicitly stop and remove containers by name before starting new ones:

```bash
docker stop notes-app notes-nginx 2>/dev/null || true
docker rm notes-app notes-nginx 2>/dev/null || true
docker compose up -d --remove-orphans
```

## 8. `docker compose down` Fails on Stale Containers

**Symptom**: `docker compose down --remove-orphans` only removes the network, but the old containers remain.

**Cause**: `docker compose down` only manages containers that belong to the current compose project (identified by project name, derived from directory path + env). If old containers were created with a different project name (e.g., different working directory or missing env vars), `down` won't find them.

**Fix**: Don't rely on `docker compose down` for cleanup. Use `docker stop` + `docker rm` by container name directly — this works regardless of how the containers were created.

## 9. `set -e` Prevents Rollback Execution

**Symptom**: Deployment fails, rollback code never runs, service stays down.

**Cause**: With `set -e`, if `docker compose up -d` fails, the shell exits immediately. The rollback block further down in the script never executes.

**Fix**: Move rollback logic outside of the main flow as a separate conditional check after the health check loop, not inline in the failure path. Use `set -euo pipefail` for stricter checking but ensure every potential failure point either has explicit error handling or is expected to fail gracefully (`|| true`).

## 10. `docker compose ps` Requires All Variables to Be Set

**Symptom**: `docker compose ps` fails with `service "app" has neither an image nor a build context specified`.

**Cause**: `docker-compose` parses the full `compose.yaml` even for `ps`. If `APP_IMAGE` (set via `export`) is not yet available, the `image: ${APP_IMAGE}` reference fails validation.

**Fix**: Capture the current container state with `docker inspect` directly instead of going through compose:

```bash
PREV_IMAGE=$(docker inspect --format='{{.Config.Image}}' notes-app 2>/dev/null || echo "none")
```

## 11. Docker Hub Mirror Acceleration (Domestic)

**Symptom**: `docker pull` extremely slow or times out in certain regions.

**Cause**: Docker Hub is blocked or throttled by network conditions.

**Fix**: Configure a mirror registry in `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": ["https://<your-mirror>.mirror.aliyuncs.com"]
}
```

For Alibaba Cloud ECS, use the ACR mirror provided by your instance region. Restart Docker after changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

> **Note**: Some mirrors may become unavailable over time. Alibaba Cloud ACR is generally the most reliable option for domestic ECS instances.
