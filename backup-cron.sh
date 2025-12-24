#!/bin/bash
# Database backup script for abairt
# Run daily at 2 AM

set -e

CONTAINER_NAME=$(docker ps | grep abairt_rails | awk '{print $1}' | head -1)
BACKUP_DATE=$(date +%Y%m%d-%H%M)
BACKUP_DIR="/tmp/db-backup-$$"
S3_BUCKET="s3://abairt-db/backups"

# Exit if no container found
if [ -z "$CONTAINER_NAME" ]; then
    echo "Error: No Rails container found"
    exit 1
fi

mkdir -p $BACKUP_DIR

# Copy database files
docker cp $CONTAINER_NAME:/rails/db/production.sqlite3 $BACKUP_DIR/production.sqlite3
docker cp $CONTAINER_NAME:/rails/db/production.sqlite3-wal $BACKUP_DIR/production.sqlite3-wal 2>/dev/null || true
docker cp $CONTAINER_NAME:/rails/db/production.sqlite3-shm $BACKUP_DIR/production.sqlite3-shm 2>/dev/null || true

# Create tarball
cd $BACKUP_DIR
tar czf /tmp/abairt-db-backup-$BACKUP_DATE.tar.gz production.sqlite3*

# Upload to S3
/usr/local/bin/aws s3 cp /tmp/abairt-db-backup-$BACKUP_DATE.tar.gz $S3_BUCKET/abairt-db-backup-$BACKUP_DATE.tar.gz

# Cleanup old S3 backups (keep last 30 days)
/usr/local/bin/aws s3 ls $S3_BUCKET/ | while read -r line; do
    createDate=$(echo $line | awk {'print $1" "$2'})
    createDate=$(date -d "$createDate" +%s)
    olderThan=$(date -d "30 days ago" +%s)
    if [[ $createDate -lt $olderThan ]]; then
        fileName=$(echo $line | awk {'print $4'})
        if [[ $fileName != "" ]]; then
            /usr/local/bin/aws s3 rm $S3_BUCKET/$fileName
        fi
    fi
done

# Cleanup temp files
rm -rf $BACKUP_DIR /tmp/abairt-db-backup-$BACKUP_DATE.tar.gz

echo "$(date): Backup completed and uploaded to $S3_BUCKET/abairt-db-backup-$BACKUP_DATE.tar.gz"
