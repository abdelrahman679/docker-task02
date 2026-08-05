#!/bin/sh

# Read the database password from the Docker secret
PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")

# Generate a timestamp for the backup filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Create the backup
mysqldump \
  -h "$MYSQL_HOST" \
  -u "$MYSQL_USER" \
  -p"$PASSWORD" \
  "$MYSQL_DATABASE" \
  > "/backup/data/backup-${TIMESTAMP}.sql"

# Check whether the backup succeeded
if [ $? -eq 0 ]; then
    echo "Backup completed successfully: backup-${TIMESTAMP}.sql"
else
    echo "Backup failed!"
    exit 1
fi
