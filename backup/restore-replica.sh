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

# Replication settings (must match replication-user.sql / primary config)
PRIMARY_HOST="db-primary"
REPL_USER="replicator"
REPL_PASSWORD="replica_password"

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

if [ ! -f "$BACKUP_DIR/xtrabackup_binlog_info" ]; then
    echo "ERROR: xtrabackup_binlog_info not found in backup dir."
    echo "  Was --prepare run successfully on this backup?"
    exit 1
fi

echo "======================================"
echo " MariaDB Replica Restore"
echo "======================================"
echo "Backup : $BACKUP_DIR"
echo

# =====================================
# Extract GTID from backup metadata
# =====================================
# xtrabackup_binlog_info format: <binlog file>\t<position>\t<GTID>
BACKUP_GTID=$(awk '{print $3}' "$BACKUP_DIR/xtrabackup_binlog_info")

if [ -z "$BACKUP_GTID" ]; then
    echo "ERROR: Could not read GTID from xtrabackup_binlog_info"
    cat "$BACKUP_DIR/xtrabackup_binlog_info"
    exit 1
fi

echo "Recovered GTID from backup: $BACKUP_GTID"
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

# =====================================
# Wait for replica to become healthy
# =====================================
echo "Waiting for replica to become healthy..."
ATTEMPTS=0
MAX_ATTEMPTS=30

until [ "$(docker inspect -f '{{.State.Health.Status}}' "$REPLICA_CONTAINER" 2>/dev/null)" = "healthy" ]; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
        echo "ERROR: Replica did not become healthy in time."
        exit 1
    fi
    sleep 2
done

echo "Replica is healthy."
echo

# =====================================
# Bootstrap replication using recovered GTID
# =====================================
echo "Configuring replication (gtid_slave_pos=$BACKUP_GTID)..."

DB_ROOT_PASSWORD=$(cat "$DB_PASSWORD_FILE")

docker compose exec -T "$REPLICA_SERVICE" \
    mariadb -uroot -p"$DB_ROOT_PASSWORD" <<SQL
STOP SLAVE;
SET GLOBAL gtid_slave_pos = '${BACKUP_GTID}';
CHANGE MASTER TO
  MASTER_HOST='${PRIMARY_HOST}',
  MASTER_USER='${REPL_USER}',
  MASTER_PASSWORD='${REPL_PASSWORD}',
  MASTER_USE_GTID=slave_pos;
START SLAVE;
SQL

echo
echo "Verifying replication status..."
docker compose exec -T "$REPLICA_SERVICE" \
    mariadb -uroot -p"$DB_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" \
    | grep -E "Slave_IO_Running|Slave_SQL_Running|Last_Error|Seconds_Behind_Master"

echo
echo "======================================"
echo " Replica restored and replication started."
echo "======================================"
