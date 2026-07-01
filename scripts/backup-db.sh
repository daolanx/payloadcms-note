#!/bin/bash
# Backup SQLite database
# Usage: bash scripts/backup-db.sh
# Run on ECS via BaoTa scheduled task

set -euo pipefail

DB_FILE="/opt/notes/db/database.db"
BACKUP_DIR="/opt/notes/db/backups"
KEEP_DAYS=7

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/database-$TIMESTAMP.db"

mkdir -p "$BACKUP_DIR"
cp "$DB_FILE" "$BACKUP_FILE"
echo "✓ Backup: $BACKUP_FILE"

# Clean old backups
find "$BACKUP_DIR" -name "database-*.db" -mtime +$KEEP_DAYS -delete 2>/dev/null
echo "✓ Done (kept last $KEEP_DAYS days)"
