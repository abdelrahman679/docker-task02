#!/bin/bash
set -e

# ============================
# Configuration
# ============================
PROJECT_NAME="react-express-mysql"
REPLICA_VOLUME="${PROJECT_NAME}_db-replica-data"
BACKUP_ROOT="$(dirname "$0")/physical"
MARIADB_IMAGE="mariadb:10.6"

# ============================
# Select backup
# ============================
if [ "$1" = "latest" ] || [ -z "$1" ]; then
    BACKUP_DIR=$(ls -td "$BACKUP_ROOT"/* | head -1)
else
    BACKUP_DIR="$BACKUP_ROOT/$1"
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup not found:"
    echo "  $BACKUP_DIR"
    exit 1
fi

echo "===================================="
echo "Replica Restore"
echo "===================================="
echo "Replica volume : $REPLICA_VOLUME"
echo "Backup         : $BACKUP_DIR"
echo

# ============================
# Restore
# ============================
docker run --rm \
    -v "${REPLICA_VOLUME}:/var/lib/mysql" \
    -v "${BACKUP_DIR}:/backup:ro" \
    "$MARIADB_IMAGE" \
    bash -c '
        set -e

        echo "Cleaning replica volume..."
        rm -rf /var/lib/mysql/*

        echo "Restoring backup..."
        mariadb-backup \
            --copy-back \
            --target-dir=/backup

        echo "Fixing ownership..."
        chown -R mysql:mysql /var/lib/mysql

        echo "Restore completed successfully."
    '

echo
echo "Done."
