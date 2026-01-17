#!/bin/bash
set -e

CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep abairt_rails | head -1)

if [ -z "$CONTAINER_NAME" ]; then
  echo "Error: No abairt_rails container found"
  exit 1
fi

BACKUP_DIR="local/backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

echo "Backing up from container: $CONTAINER_NAME"

docker cp "$CONTAINER_NAME:/rails/db/production.sqlite3" "$BACKUP_DIR/production.sqlite3"

echo "Backup complete: $BACKUP_DIR"
