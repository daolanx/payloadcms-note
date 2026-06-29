#!/bin/bash
# Generate self-signed SSL certificates if not present.
# Called automatically before docker compose up for production.
#
# Usage: ./scripts/generate-certs.sh
# Idempotent: skips generation if certs already exist.
set -e

CERT_DIR="docker/production/certs"
CERT_FILE="${CERT_DIR}/cert.pem"
KEY_FILE="${CERT_DIR}/key.pem"

if [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
  echo "✓ SSL certs already exist"
  exit 0
fi

echo "▸ Generating self-signed SSL certs..."
mkdir -p "${CERT_DIR}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}" \
  -subj "/CN=localhost" 2>/dev/null

echo "✓ Self-signed certs generated (valid 365 days)"
echo "  → ${CERT_FILE}"
echo "  → ${KEY_FILE}"
echo "  Replace with real certs and redeploy when ready"
