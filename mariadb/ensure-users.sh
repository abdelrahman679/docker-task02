#!/bin/bash
set -e

PASSWORD="$(cat /run/secrets/db-password)"

wait_for_mysql() {
  until mysqladmin ping -h "$1" -uroot -p"$PASSWORD" --silent >/dev/null 2>&1; do
    echo "Waiting for $1..."
    sleep 2
  done
}

echo "==> Waiting for db-primary"
wait_for_mysql db-primary

echo "==> Applying init-users.sql on db-primary (idempotent: IF NOT EXISTS)"
mysql -h db-primary -uroot -p"$PASSWORD" < /init-users.sql

echo "==> Waiting for db-replica"
wait_for_mysql db-replica

echo "==> Confirming maxscale user replicated to db-replica"
COUNT=0
for i in $(seq 1 10); do
  COUNT=$(mysql -h db-replica -uroot -p"$PASSWORD" -N -e \
    "SELECT COUNT(*) FROM mysql.user WHERE user='maxscale';")
  [ "$COUNT" -ge 1 ] && break
  echo "    not replicated yet, retry $i/10..."
  sleep 2
done

if [ "$COUNT" -lt 1 ]; then
  echo "==> WARNING: replication didn't carry the user in time — applying directly on db-replica."
  mysql -h db-replica -uroot -p"$PASSWORD" < /init-users.sql
fi

echo "==> User provisioning guaranteed on both nodes."
