#!/bin/sh
set -e

DB_FILE="/app/data/database.db"
SCHEMA_FILE="/app/init-db.sql"

# Ensure data directory exists
mkdir -p /app/data

# If database is empty or missing tables, initialize from schema
if [ ! -s "$DB_FILE" ] || ! sqlite3 "$DB_FILE" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='users';" | grep -q '1'; then
  echo "Initializing database..."
  sqlite3 "$DB_FILE" < "$SCHEMA_FILE"
  echo "Database initialized."
fi

# Start the Next.js server
exec node server.js
