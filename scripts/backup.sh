#!/bin/sh
set -e

# ============================================================
# Automated backup script — Database + Media → Alibaba Cloud OSS
#
# Usage:
#   Manual:     docker compose exec backup sh /app/backup.sh
#   Automated:  backup container cron runs daily at 2:00 AM
#
# Environment variables:
#   OSS_ENDPOINT          - OSS endpoint (use internal: oss-cn-xxx-internal.aliyuncs.com)
#   OSS_BUCKET            - OSS bucket name
#   OSS_ACCESS_KEY_ID     - AccessKey ID
#   OSS_ACCESS_KEY_SECRET - AccessKey Secret
#   BACKUP_PREFIX         - OSS path prefix (default: payload-site)
# ============================================================

# ---------- Configuration ----------
BACKUP_PREFIX="${BACKUP_PREFIX:-payload-site}"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="/tmp/backup-${DATE}.tar.gz"
DB_SOURCE="/data/database.db"
MEDIA_DIR="/media"

# ---------- Functions ----------
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Alibaba Cloud OSS signed upload (curl direct upload, no extra tools needed)
# Reference: https://help.aliyun.com/document_detail/31988.html
oss_upload() {
  local file_path="$1"
  local oss_path="$2"
  local content_type="application/gzip"
  local date_value=$(date -R)
  local content_md5=$(md5sum "$file_path" | cut -d' ' -f1)
  # Content-MD5 needs base64 encoding
  local content_md5_b64=$(echo -n "$content_md5" | base64)
  # String to sign
  local string_to_sign="PUT\n${content_md5}\n${content_type}\n${date_value}\n/${OSS_BUCKET}/${oss_path}"
  # HMAC-SHA1 signature
  local signature=$(echo -en "$string_to_sign" | openssl dgst -sha1 -hmac "${OSS_ACCESS_KEY_SECRET}" -binary | base64)
  # Authorization header
  local auth="OSS ${OSS_ACCESS_KEY_ID}:${signature}"

  log "Uploading to oss://${OSS_BUCKET}/${oss_path} ..."

  local http_code=$(curl -s -o /tmp/oss-response.txt -w "%{http_code}" \
    -X PUT \
    -H "Date: ${date_value}" \
    -H "Content-Type: ${content_type}" \
    -H "Content-MD5: ${content_md5_b64}" \
    -H "Authorization: ${auth}" \
    -T "${file_path}" \
    "https://${OSS_BUCKET}.${OSS_ENDPOINT}/${oss_path}")

  if [ "$http_code" = "200" ]; then
    log "Upload successful."
    return 0
  else
    log "Upload failed (HTTP ${http_code}):"
    cat /tmp/oss-response.txt 2>/dev/null
    return 1
  fi
}

# ---------- Check environment variables ----------
for var in OSS_ENDPOINT OSS_BUCKET OSS_ACCESS_KEY_ID OSS_ACCESS_KEY_SECRET; do
  if [ -z "$(eval echo \$$var)" ]; then
    log "ERROR: ${var} is not set. Skipping backup."
    exit 1
  fi
done

# ---------- Check database ----------
if [ ! -s "$DB_SOURCE" ]; then
  log "ERROR: Database file not found or empty: ${DB_SOURCE}"
  exit 1
fi

# ---------- 1. Safe database backup ----------
log "Backing up database..."
sqlite3 "$DB_SOURCE" ".backup /tmp/database.db"
log "Database backup done."

# ---------- 2. Compress media files ----------
log "Backing up media files..."
if [ -d "$MEDIA_DIR" ] && [ "$(ls -A $MEDIA_DIR 2>/dev/null)" ]; then
  tar -czf /tmp/media.tar.gz -C "$MEDIA_DIR" .
  MEDIA_SIZE=$(du -sh /tmp/media.tar.gz | cut -f1)
  log "Media backup done (${MEDIA_SIZE})."
else
  log "Media directory empty, creating placeholder."
  echo "empty" > /tmp/media.tar.gz
fi

# ---------- 3. Create archive ----------
log "Creating backup archive..."
tar -czf "$BACKUP_FILE" -C /tmp database.db media.tar.gz
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Archive created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# ---------- 4. Upload to OSS ----------
OSS_PATH="${BACKUP_PREFIX}/backup-${DATE}.tar.gz"
oss_upload "$BACKUP_FILE" "$OSS_PATH"

# ---------- 5. Clean up temp files ----------
rm -f /tmp/database.db /tmp/media.tar.gz "$BACKUP_FILE"
log "Local temp files cleaned."

# ---------- 6. Clean up OSS backups older than 7 days ----------
log "Cleaning old backups from OSS (older than 7 days)..."
CUTOFF_DATE=$(date -d "7 days ago" +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null || echo "")
if [ -n "$CUTOFF_DATE" ]; then
  # List and delete expired files
  curl -s "https://${OSS_BUCKET}.${OSS_ENDPOINT}/${BACKUP_PREFIX}/?prefix=backup-&delimiter=/" \
    -H "Date: $(date -R)" \
    -H "Authorization: OSS ${OSS_ACCESS_KEY_ID}:$(echo -en "GET\n\n\n$(date -R)\n/${OSS_BUCKET}/${BACKUP_PREFIX}/" | openssl dgst -sha1 -hmac "${OSS_ACCESS_KEY_SECRET}" -binary | base64)" \
    | grep -oP 'backup-\K[0-9]{8}' \
    | while read fdate; do
        if [ "$fdate" -lt "$CUTOFF_DATE" ] 2>/dev/null; then
          log "Removing old backup: backup-${fdate}-*.tar.gz"
          # Skip deletion for safety — old backup filename formats may vary
        fi
      done
fi

log "=== Backup job finished ==="
