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

## 6. Docker Hub Mirror Acceleration (Domestic)

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
