#!/bin/bash
set -e

# ============================================================
# Data recovery script — Database + Media files
#
# Usage:
#   ./scripts/restore.sh list                      List local backups
#   ./scripts/restore.sh db <backup-file>          Restore database
#   ./scripts/restore.sh media <backup-file>       Restore media files
#   ./scripts/restore.sh full <backup-file>        Full restore (database + media)
#   ./scripts/restore.sh oss-list                  List backups on OSS
#   ./scripts/restore.sh oss <backup-name|latest>  Download and restore from OSS
#
# Arguments:
#   <backup-file>  Local backup file path (.db or .tar.gz)
#   <backup-name>  OSS backup filename (e.g. backup-20260622-120000.tar.gz)
# ============================================================

# ---------- Configuration ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUPS_DIR="${PROJECT_DIR}/backups"
DATA_DIR="${PROJECT_DIR}/data"
MEDIA_DIR="${PROJECT_DIR}/media"

# Load OSS config from .env file if present
if [ -f "${PROJECT_DIR}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_DIR}/.env"
  set +a
fi

OSS_ENDPOINT="${OSS_ENDPOINT:-}"
OSS_BUCKET="${OSS_BUCKET:-}"
OSS_ACCESS_KEY_ID="${OSS_ACCESS_KEY_ID:-}"
OSS_ACCESS_KEY_SECRET="${OSS_ACCESS_KEY_SECRET:-}"
BACKUP_PREFIX="${BACKUP_PREFIX:-payload-site}"

# ---------- Color output ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $1"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"; }
info()  { echo -e "${CYAN}$1${NC}"; }

# ---------- Check if Docker is running ----------
check_docker() {
  if ! docker info > /dev/null 2>&1; then
    error "Docker is not running. Please start Docker first."
    exit 1
  fi
}

# ---------- Check if container is running ----------
check_container() {
  local container="$1"
  if ! docker compose -f "${PROJECT_DIR}/docker-compose.yml" ps "$container" 2>/dev/null | grep -q "Up"; then
    warn "Container $container is not running. Some operations may be unavailable."
    return 1
  fi
  return 0
}

# ============================================================
# Command: list — List local backups
# ============================================================
cmd_list() {
  log "Scanning local backup directory..."
  if [ ! -d "$BACKUPS_DIR" ]; then
    warn "Backup directory does not exist: $BACKUPS_DIR"
    return 0
  fi

  local count=0
  echo ""
  info "=== Local Database Backups (.db) ==="
  for f in "$BACKUPS_DIR"/database-*.db; do
    [ -f "$f" ] || continue
    count=$((count + 1))
    local size name mtime
    size=$(du -h "$f" | cut -f1)
    name=$(basename "$f")
    mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || stat -c "%y" "$f" 2>/dev/null | cut -d. -f1)
    printf "  ${GREEN}%2d${NC}. %-40s %6s  %s\n" "$count" "$name" "$size" "$mtime"
  done
  if [ "$count" -eq 0 ]; then
    warn "No database backup files found."
  fi

  echo ""
  info "=== Local Full Backups (.tar.gz) ==="
  local tar_count=0
  for f in "$BACKUPS_DIR"/*.tar.gz; do
    [ -f "$f" ] || continue
    tar_count=$((tar_count + 1))
    count=$((count + 1))
    local size name mtime
    size=$(du -h "$f" | cut -f1)
    name=$(basename "$f")
    mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || stat -c "%y" "$f" 2>/dev/null | cut -d. -f1)
    printf "  ${GREEN}%2d${NC}. %-45s %6s  %s\n" "$count" "$name" "$size" "$mtime"
  done
  if [ "$tar_count" -eq 0 ]; then
    warn "No full backup files found."
  fi

  echo ""
  log "Found $count backup file(s) total."
}

# ============================================================
# Command: db — Restore database
# ============================================================
cmd_db() {
  local backup_file="$1"
  if [ -z "$backup_file" ]; then
    error "Please specify a backup file path."
    echo "Usage: $0 db <backup-file.db>"
    exit 1
  fi

  if [ ! -f "$backup_file" ]; then
    error "Backup file does not exist: $backup_file"
    exit 1
  fi

  log "Preparing to restore database..."

  # Ensure data directory exists
  mkdir -p "$DATA_DIR"

  # Back up current database first
  if [ -f "${DATA_DIR}/database.db" ]; then
    local current_backup="${BACKUPS_DIR}/database-before-restore-$(date +%Y%m%d-%H%M%S).db"
    mkdir -p "$BACKUPS_DIR"
    cp "${DATA_DIR}/database.db" "$current_backup"
    log "Current database backed up to: $current_backup"
  fi

  # Use Docker container if available
  if check_container "web" 2>/dev/null; then
    log "Restoring via Docker container..."
    docker compose -f "${PROJECT_DIR}/docker-compose.yml" exec -T web \
      sh -c "cp /dev/stdin /app/data/database.db" < "$backup_file"
  else
    log "Copying directly to data directory..."
    cp "$backup_file" "${DATA_DIR}/database.db"
  fi

  log "Database restore complete ✓"
  info "File: ${DATA_DIR}/database.db"
}

# ============================================================
# Command: media — Restore media files
# ============================================================
cmd_media() {
  local backup_file="$1"
  if [ -z "$backup_file" ]; then
    error "Please specify a backup file path."
    echo "Usage: $0 media <backup-file.tar.gz>"
    exit 1
  fi

  if [ ! -f "$backup_file" ]; then
    error "Backup file does not exist: $backup_file"
    exit 1
  fi

  log "Preparing to restore media files..."

  # Ensure media directory exists
  mkdir -p "$MEDIA_DIR"

  # Back up current media files first
  if [ -d "$MEDIA_DIR" ] && [ "$(ls -A "$MEDIA_DIR" 2>/dev/null)" ]; then
    local current_backup="${BACKUPS_DIR}/media-before-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
    mkdir -p "$BACKUPS_DIR"
    tar -czf "$current_backup" -C "$MEDIA_DIR" .
    log "Current media files backed up to: $current_backup"
  fi

  log "Extracting media files..."
  tar -xzf "$backup_file" -C "$MEDIA_DIR"

  local file_count
  file_count=$(find "$MEDIA_DIR" -type f | wc -l | tr -d ' ')
  log "Media restore complete ✓"
  info "Restored ${file_count} file(s) to ${MEDIA_DIR}"
}

# ============================================================
# Command: full — Full restore (database + media)
# ============================================================
cmd_full() {
  local backup_file="$1"
  if [ -z "$backup_file" ]; then
    error "Please specify a backup file path."
    echo "Usage: $0 full <backup-file.tar.gz>"
    exit 1
  fi

  if [ ! -f "$backup_file" ]; then
    error "Backup file does not exist: $backup_file"
    exit 1
  fi

  log "Preparing full restore..."
  echo ""

  # Create temp directory
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" EXIT

  # Extract backup archive
  log "Extracting backup archive..."
  tar -xzf "$backup_file" -C "$tmp_dir"

  # Restore database
  if [ -f "${tmp_dir}/database.db" ]; then
    echo ""
    cmd_db "${tmp_dir}/database.db"
  else
    warn "database.db not found in backup archive, skipping database restore."
  fi

  # Restore media files
  if [ -f "${tmp_dir}/media.tar.gz" ]; then
    echo ""
    cmd_media "${tmp_dir}/media.tar.gz"
  else
    warn "media.tar.gz not found in backup archive, skipping media restore."
  fi

  echo ""
  log "Full restore complete ✓"
}

# ============================================================
# Command: oss-list — List backups on OSS
# ============================================================
cmd_oss_list() {
  check_oss_config

  log "Querying OSS backup list..."

  local date_value
  date_value=$(date -R)
  local string_to_sign="GET\n\n\n${date_value}\n/${OSS_BUCKET}/${BACKUP_PREFIX}/"
  local signature
  signature=$(echo -en "$string_to_sign" | openssl dgst -sha1 -hmac "${OSS_ACCESS_KEY_SECRET}" -binary | base64)
  local auth="OSS ${OSS_ACCESS_KEY_ID}:${signature}"

  local response
  response=$(curl -s \
    -H "Date: ${date_value}" \
    -H "Authorization: ${auth}" \
    "https://${OSS_BUCKET}.${OSS_ENDPOINT}/${BACKUP_PREFIX}/?prefix=backup-&delimiter=/")

  if [ -z "$response" ]; then
    warn "No backups found on OSS."
    return 0
  fi

  echo ""
  info "=== OSS Backup List (oss://${OSS_BUCKET}/${BACKUP_PREFIX}/) ==="
  echo "$response" \
    | grep -oE '<Key>[^<]+</Key>' \
    | sed 's/<[^>]*>//g' \
    | sort -r \
    | while IFS= read -r key; do
        local name date_part
        name=$(basename "$key")
        date_part=$(echo "$name" | grep -oE '[0-9]{8}-[0-9]{6}')
        printf "  ${GREEN}•${NC} %-45s %s\n" "$name" "$date_part"
      done
  echo ""
}

# ============================================================
# Command: oss — Download and restore from OSS
# ============================================================
cmd_oss() {
  local backup_name="$1"
  if [ -z "$backup_name" ]; then
    error "Please specify an OSS backup filename."
    echo "Usage: $0 oss <backup-name>"
    echo "      $0 oss latest              # Restore the latest backup"
    exit 1
  fi

  check_oss_config

  # If "latest" is specified, fetch the most recent backup name
  if [ "$backup_name" = "latest" ]; then
    log "Finding latest backup..."
    local date_value
    date_value=$(date -R)
    local string_to_sign="GET\n\n\n${date_value}\n/${OSS_BUCKET}/${BACKUP_PREFIX}/"
    local signature
    signature=$(echo -en "$string_to_sign" | openssl dgst -sha1 -hmac "${OSS_ACCESS_KEY_SECRET}" -binary | base64)
    local auth="OSS ${OSS_ACCESS_KEY_ID}:${signature}"

    backup_name=$(curl -s \
      -H "Date: ${date_value}" \
      -H "Authorization: ${auth}" \
      "https://${OSS_BUCKET}.${OSS_ENDPOINT}/${BACKUP_PREFIX}/?prefix=backup-&delimiter=/" \
      | grep -oE '<Key>[^<]+</Key>' \
      | sed 's/<[^>]*>//g' \
      | sort -r \
      | head -1 \
      | xargs -r basename)

    if [ -z "$backup_name" ]; then
      error "No backups found on OSS."
      exit 1
    fi
    log "Latest backup: $backup_name"
  fi

  # Download backup
  mkdir -p "$BACKUPS_DIR"
  local local_file="${BACKUPS_DIR}/${backup_name}"

  log "Downloading from OSS: ${BACKUP_PREFIX}/${backup_name} ..."

  local date_value
  date_value=$(date -R)
  local string_to_sign="GET\n\n\n${date_value}\n/${OSS_BUCKET}/${BACKUP_PREFIX}/${backup_name}"
  local signature
  signature=$(echo -en "$string_to_sign" | openssl dgst -sha1 -hmac "${OSS_ACCESS_KEY_SECRET}" -binary | base64)
  local auth="OSS ${OSS_ACCESS_KEY_ID}:${signature}"

  local http_code
  http_code=$(curl -s -o "$local_file" -w "%{http_code}" \
    -H "Date: ${date_value}" \
    -H "Authorization: ${auth}" \
    "https://${OSS_BUCKET}.${OSS_ENDPOINT}/${BACKUP_PREFIX}/${backup_name}")

  if [ "$http_code" != "200" ]; then
    error "Download failed (HTTP ${http_code})"
    rm -f "$local_file"
    exit 1
  fi

  local size
  size=$(du -h "$local_file" | cut -f1)
  log "Download complete: ${local_file} (${size})"

  # Perform full restore
  echo ""
  cmd_full "$local_file"
}

# ============================================================
# Helper: Check OSS config
# ============================================================
check_oss_config() {
  local missing=0
  for var in OSS_ENDPOINT OSS_BUCKET OSS_ACCESS_KEY_ID OSS_ACCESS_KEY_SECRET; do
    eval "local val=\$$var"
    if [ -z "$val" ]; then
      error "Missing environment variable: $var"
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    echo ""
    error "Please configure OSS settings in .env or environment variables:"
    echo "  OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com"
    echo "  OSS_BUCKET=your-bucket"
    echo "  OSS_ACCESS_KEY_ID=your-key-id"
    echo "  OSS_ACCESS_KEY_SECRET=your-key-secret"
    exit 1
  fi
}

# ============================================================
# Help
# ============================================================
usage() {
  echo ""
  info "Data Recovery Tool — Payload CMS"
  echo ""
  echo "Usage:"
  echo "  $0 list                      List local backup files"
  echo "  $0 db <file.db>              Restore database"
  echo "  $0 media <file.tar.gz>       Restore media files"
  echo "  $0 full <file.tar.gz>        Full restore (database + media)"
  echo "  $0 oss-list                  List backups on OSS"
  echo "  $0 oss <name|latest>         Download and restore from OSS"
  echo ""
  echo "Examples:"
  echo "  $0 list"
  echo "  $0 db ./backups/database-20260622.db"
  echo "  $0 full ./backups/backup-20260622-120000.tar.gz"
  echo "  $0 oss latest"
  echo ""
}

# ============================================================
# Main entry point
# ============================================================
COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  list)
    cmd_list
    ;;
  db)
    cmd_db "$1"
    ;;
  media)
    cmd_media "$1"
    ;;
  full)
    cmd_full "$1"
    ;;
  oss-list)
    cmd_oss_list
    ;;
  oss)
    cmd_oss "$1"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    error "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
