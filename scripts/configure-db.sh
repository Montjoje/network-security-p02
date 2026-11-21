#!/usr/bin/env bash
# =====================================================================
# P02: Skrypt automatyzujacy konfiguracje i hardening serwera DB-SRV
# Odpowiedzialnosc: Osoba 4 (DB i hardening)
# Plik: scripts/configure-db.sh
#
# Uzycie:
#   sudo ./scripts/configure-db.sh
#   lub z przekazaniem hasla w zmiennej:
#   DB_PASSWORD='twoje_haslo' sudo -E ./scripts/configure-db.sh
# =====================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Weryfikacja uprawnien roota
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root (e.g. sudo $0)" >&2
  exit 1
fi

echo "========================================================"
echo " Starting Automated DB-SRV Configuration (P02)          "
echo "========================================================"

# 2. Pobranie hasla dla uzytkownika webapp_user (bez zapisywania w kodzie)
PASSWORD="${DB_PASSWORD:-}"
if [ -z "$PASSWORD" ]; then
  echo -n "Enter password for webapp_user database account: "
  read -rs PASSWORD
  echo
fi

if [ -z "$PASSWORD" ]; then
  echo "ERROR: Password cannot be empty!" >&2
  exit 1
fi

# 3. Instalacja wymaganych pakietow
echo "[1/7] Installing packages (PostgreSQL, nftables, auditd, unattended-upgrades)..."
apt-get update -qq
apt-get install -y -qq postgresql postgresql-contrib nftables auditd unattended-upgrades apt-listchanges

# Wykrycie wersji klastra PostgreSQL
PG_VER=$(pg_lsclusters -h | head -n 1 | awk '{print $1}')
if [ -z "$PG_VER" ]; then
  PG_VER="17"
fi
PG_CONF_DIR="/etc/postgresql/$PG_VER/main"

# 4. Wdrozenie konfiguracji postgresql.conf
echo "[2/7] Configuring postgresql.conf (192.168.30.10, SCRAM-SHA-256, logging)..."
mkdir -p "$PG_CONF_DIR/conf.d"
cp "$PROJECT_ROOT/database/postgresql.conf.fragment" "$PG_CONF_DIR/conf.d/p02-hardening.conf"

# 5. Wdrozenie restrykcyjnego pg_hba.conf
echo "[3/7] Configuring pg_hba.conf (access restricted to APP-SRV)..."
if [ ! -f "$PG_CONF_DIR/pg_hba.conf.orig" ]; then
  cp "$PG_CONF_DIR/pg_hba.conf" "$PG_CONF_DIR/pg_hba.conf.orig"
fi
cp "$PROJECT_ROOT/database/pg_hba.conf.fragment" "$PG_CONF_DIR/pg_hba.conf"

# Restart uslugi bazy danych
systemctl restart postgresql

# 6. Inicjalizacja bazy, uzytkownika i tabeli messages
echo "[4/7] Initializing webapp_db, webapp_user role, and messages table..."
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='webapp_db'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE webapp_db;"

sudo -u postgres psql -c "DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'webapp_user') THEN
    CREATE ROLE webapp_user WITH LOGIN PASSWORD '$PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
  ELSE
    ALTER ROLE webapp_user WITH PASSWORD '$PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
  END IF;
END
\$\$;"

# Zaaplikowanie uprawnien i tabeli z init.sql (przekierowanie stdin, aby uzytkownik postgres nie musial miec uprawnien do sciezki w /home)
sudo -u postgres psql -d webapp_db < "$PROJECT_ROOT/database/init.sql" > /dev/null

# 7. Wdrozenie firewalla hostowego nftables
echo "[5/7] Deploying nftables host firewall..."
cp "$PROJECT_ROOT/database/nftables.conf" /etc/nftables.conf
nft -f /etc/nftables.conf
systemctl enable --now nftables

# 8. Hardening uslugi OpenSSH
echo "[6/7] Hardening OpenSSH server (PermitRootLogin no, limits)..."
mkdir -p /etc/ssh/sshd_config.d
cat << "EOF" > /etc/ssh/sshd_config.d/p02-hardening.conf
PermitRootLogin no
AllowUsers vboxuser
MaxAuthTries 3
LoginGraceTime 30
PermitEmptyPasswords no
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
sshd -t
systemctl reload ssh || systemctl restart ssh

# 9. Konfiguracja podsystemu audytu auditd i aktualizacji automatycznych
echo "[7/7] Configuring auditd rules and unattended-upgrades..."
cat << "EOF" > /etc/audit/rules.d/p02-db-srv.rules
-w /etc/postgresql/ -p wa -k db_config_change
-w /etc/nftables.conf -p wa -k firewall_change
-w /etc/ssh/ -p wa -k ssh_config_change
-w /etc/passwd -p wa -k identity_change
-w /etc/shadow -p wa -k identity_change
EOF
augenrules --load
systemctl enable --now auditd

cat << "EOF" > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades

echo "========================================================"
echo " DB-SRV Server Configuration Completed Successfully!    "
echo " You can now run the test suite:                        "
echo " DB_PASSWORD='...' $PROJECT_ROOT/tests/database-tests.sh"
echo "========================================================"
