#!/bin/sh

set -e

# Read the database password from the Docker secret
PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")

# Generate a timestamp for the backup directory
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Directory where the backup will be stored
TARGET_DIR="/backup/physical/${TIMESTAMP}"

# Create the target directory
mkdir -p "$TARGET_DIR"

echo "=== Starting physical backup ==="

mariadb-backup \
  --backup \
  --host="$MYSQL_HOST" \
  --user="$MYSQL_USER" \
  --password="$PASSWORD" \
  --target-dir="$TARGET_DIR"

echo "=== Backup completed successfully ==="

echo "=== Preparing backup ==="

mariadb-backup \
  --prepare \
  --target-dir="$TARGET_DIR"

echo "=== Backup prepared successfully ==="
