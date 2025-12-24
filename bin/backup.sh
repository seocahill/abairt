#!/bin/bash
set -e

CONTAINER_NAME=$(docker ps | grep abairt_rails | awk '{print $1}' | head -1)
BACKUP_DATE=$(date +%Y%m%d-%H%M)
BACKUP_DIR="/tmp/db-backup"
S3_BUCKET="s3://abairt-db/backups"

mkdir -p $BACKUP_DIR

# Copy database files
docker cp $CONTAINER_NAME:/rails/db/production.sqlite3 $BACKUP_DIR/production.sqlite3
docker cp $CONTAINER_NAME:/rails/db/production.sqlite3-wal $BACKUP_DIR/production.sqlite3-wal 2>/dev/null || true
docker cp $CONTAINER_NAME:/rails/db/production.sqlite3-shm $BACKUP_DIR/production.sqlite3-shm 2>/dev/null || true

# Create tarball
cd $BACKUP_DIR
tar czf /tmp/abairt-db-backup-$BACKUP_DATE.tar.gz production.sqlite3*

# Upload to S3
aws s3 cp /tmp/abairt-db-backup-$BACKUP_DATE.tar.gz $S3_BUCKET/abairt-db-backup-$BACKUP_DATE.tar.gz

# Cleanup old local backups (keep last 7 days)
find /tmp -name "abairt-db-backup-*.tar.gz" -mtime +7 -delete 2>/dev/null || true

# Cleanup temp files
rm -rf $BACKUP_DIR /tmp/abairt-db-backup-$BACKUP_DATE.tar.gz

echo "Backup completed: abairt-db-backup-$BACKUP_DATE.tar.gz uploaded to $S3_BUCKET"