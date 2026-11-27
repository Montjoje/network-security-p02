#!/bin/bash
. /usr/local/lib/p02/lib.sh
log "DB-SRV: start"
cfg_if eth0 192.168.30.10/24
set_gw 192.168.30.1

# firewall hostowy DB-SRV (polityka drop, 5432 tylko z APP-SRV)
nft -f /etc/nftables.conf && log "nftables DB-SRV zaladowane"

PGV="$(ls /usr/lib/postgresql | sort -V | tail -1)"
pg_ctlcluster "$PGV" main start || true
for i in $(seq 1 60); do pg_isready -q -h 127.0.0.1 && break; sleep 1; done
pg_isready -h 127.0.0.1 || { log "BLAD: PostgreSQL nie wystartowal"; tail -20 /var/log/postgresql/*.log; }

PASSWORD="${DB_PASSWORD:-$LAB_DB_PASSWORD_DEFAULT}"
PSQL="runuser -u postgres -- psql -v ON_ERROR_STOP=1"
$PSQL -tAc "SELECT 1 FROM pg_database WHERE datname='webapp_db'" | grep -q 1 || $PSQL -c "CREATE DATABASE webapp_db;"
$PSQL -v pw="$PASSWORD" <<'SQL'
SELECT format('CREATE ROLE webapp_user WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT', :'pw')
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'webapp_user') \gexec
SELECT format('ALTER ROLE webapp_user WITH PASSWORD %L', :'pw') \gexec
SQL
$PSQL -d webapp_db < /opt/p02/init.sql >/dev/null && log "baza webapp_db i tabela messages gotowe"
log "DB-SRV gotowy (PostgreSQL ${PGV}, nasluch 192.168.30.10:5432)"
console
