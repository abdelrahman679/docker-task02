#!/bin/bash
set -e

# =====================================
# Configuration
# =====================================
PROJECT_NAME="react-express-mysql"
REPLICA_SERVICE="db-replica"
REPLICA_CONTAINER="dbrep"
REPLICA_VOLUME="${PROJECT_NAME}_db-replica-data"
BACKUP_ROOT="$(dirname "$0")/physical"
MARIADB_IMAGE="mariadb:10.6"
DB_PASSWORD_FILE="$(dirname "$0")/../db/password.txt"

if [ ! -f "$DB_PASSWORD_FILE" ]; then
    echo "ERROR: db password file not found at: $DB_PASSWORD_FILE"
    exit 1
fi

# =====================================
# Select backup
# =====================================
if [ -z "$1" ] || [ "$1" = "latest" ]; then
    BACKUP_DIR=$(ls -1d "$BACKUP_ROOT"/*/ | sort | tail -n 1 | sed 's:/*$::')
else
    BACKUP_DIR="$BACKUP_ROOT/$1"
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup not found:"
    echo "  $BACKUP_DIR"
    exit 1
fi

echo "======================================"
echo " MariaDB Replica Restore"
echo "======================================"
echo "Backup : $BACKUP_DIR"
echo

# =====================================
# Stop replica
# =====================================
echo "Stopping replica..."
docker compose stop "$REPLICA_SERVICE" 2>/dev/null || true

# =====================================
# Remove replica container
# =====================================
echo "Removing replica container..."
docker compose rm -f "$REPLICA_SERVICE" >/dev/null 2>&1 || true

# =====================================
# Remove replica volume
# =====================================
echo "Removing replica volume..."
docker volume rm "$REPLICA_VOLUME" >/dev/null 2>&1 || true

# =====================================
# Create fresh volume
# =====================================
echo "Creating fresh replica volume..."
docker volume create "$REPLICA_VOLUME" >/dev/null

# =====================================
# Restore backup (copy-back) + healthcheck cnf
# =====================================
echo "Restoring physical backup..."

docker run --rm \
    -v "${REPLICA_VOLUME}:/var/lib/mysql" \
    -v "${BACKUP_DIR}:/backup:ro" \
    -v "${DB_PASSWORD_FILE}:/run/secrets/db-password:ro" \
    "$MARIADB_IMAGE" \
    bash -c '
        set -e

        mariadb-backup \
            --copy-back \
            --target-dir=/backup

        chown -R mysql:mysql /var/lib/mysql

        # Recreate the healthcheck credentials file normally
        # written by docker-entrypoint.sh on first init — skipped
        # here because the datadir was restored, not initialized.
        PASSWORD=$(cat /run/secrets/db-password)
        cat > /var/lib/mysql/.my-healthcheck.cnf <<EOF
[client]
user=root
password=${PASSWORD}
EOF
        chmod 600 /var/lib/mysql/.my-healthcheck.cnf
        chown mysql:mysql /var/lib/mysql/.my-healthcheck.cnf
    '

# =====================================
# Start replica
# =====================================
echo "Starting replica..."
docker compose up -d "$REPLICA_SERVICE"

echo
echo "======================================"
echo " Replica restored successfully."
echo "======================================"
