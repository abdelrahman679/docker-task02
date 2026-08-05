--CREATE USER IF NOT EXISTS 'replicator'@'%' IDENTIFIED BY 'replica_password';

--GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';

--FLUSH PRIVILEGES;

-- Replication user
CREATE USER IF NOT EXISTS 'replicator'@'%' IDENTIFIED BY 'replica_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';



-- MaxScale monitor/admin user
CREATE USER IF NOT EXISTS 'maxscale'@'%' IDENTIFIED BY 'maxscale_password';

GRANT REPLICATION CLIENT ON *.* TO 'maxscale'@'%';
GRANT REPLICATION SLAVE ADMIN ON *.* TO 'maxscale'@'%';
GRANT SUPER ON *.* TO 'maxscale'@'%';

GRANT SUPER ON *.* TO 'maxscale'@'%';
GRANT SELECT ON mysql.user TO 'maxscale'@'%';
GRANT SELECT ON mysql.db TO 'maxscale'@'%';
GRANT SELECT ON mysql.tables_priv TO 'maxscale'@'%';
GRANT SELECT ON mysql.columns_priv TO 'maxscale'@'%';
GRANT SELECT ON mysql.procs_priv TO 'maxscale'@'%';
GRANT SELECT ON mysql.proxies_priv TO 'maxscale'@'%';
GRANT SELECT ON mysql.global_priv TO 'maxscale'@'%';
GRANT SELECT ON mysql.roles_mapping TO 'maxscale'@'%';

GRANT SHOW DATABASES ON *.* TO 'maxscale'@'%';
FLUSH PRIVILEGES;




CREATE USER 'exporter'@'%' IDENTIFIED BY 'exporter_password';

GRANT PROCESS ON *.* TO 'exporter'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'exporter'@'%';
GRANT SELECT ON performance_schema.* TO 'exporter'@'%';

FLUSH PRIVILEGES;
