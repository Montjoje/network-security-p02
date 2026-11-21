#!/usr/bin/env bash
# =====================================================================
# P02: Testy konfiguracyjne, bezpieczenstwa i uprawnien PostgreSQL
# Plik: tests/database-tests.sh
#
# Uzycie:
#   sudo ./tests/database-tests.sh
#   lub z podaniem hasla uzytkownika aplikacyjnego:
#   DB_PASSWORD='haslo' sudo -E ./tests/database-tests.sh
# =====================================================================

set -u

PASS=0
FAIL=0
SKIP=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }
skip() { echo "[SKIP] $1"; SKIP=$((SKIP + 1)); }

echo "======================================================"
echo " P02: Database & Security Verification (DB-SRV)       "
echo "======================================================"

# 1. Sprawdzenie stanu uslugi PostgreSQL
if systemctl is-active --quiet postgresql; then
  pass "PostgreSQL service is active"
else
  fail "PostgreSQL service is not active"
fi

# 2. Sprawdzenie autostartu uslugi
if systemctl is-enabled --quiet postgresql; then
  pass "PostgreSQL service is enabled on boot"
else
  fail "PostgreSQL service is not enabled on boot"
fi

# 3. Sprawdzenie nasluchiwania na dedykowanym IP 192.168.30.10:5432
if ss -tulpn | grep -q "192.168.30.10:5432"; then
  pass "PostgreSQL is listening on dedicated address 192.168.30.10:5432"
else
  fail "PostgreSQL is not listening on 192.168.30.10:5432"
fi

# 4. Sprawdzenie braku nasluchiwania na 0.0.0.0:5432
if ss -tulpn | grep "5432" | grep -q "0.0.0.0:5432"; then
  fail "PostgreSQL is insecurely listening on 0.0.0.0:5432"
else
  pass "PostgreSQL is NOT listening on 0.0.0.0:5432 (no wildcard)"
fi

# 5. Sprawdzenie istnienia bazy webapp_db
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='webapp_db'" 2>/dev/null || true)
if [ "$DB_EXISTS" = "1" ]; then
  pass "Database webapp_db exists"
else
  fail "Database webapp_db does not exist"
fi

# 6. Sprawdzenie istnienia uzytkownika webapp_user
USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='webapp_user'" 2>/dev/null || true)
if [ "$USER_EXISTS" = "1" ]; then
  pass "Role webapp_user exists"
else
  fail "Role webapp_user does not exist"
fi

# 7. Sprawdzenie braku uprawnien superuzytkownika (Least Privilege)
IS_SUPER=$(sudo -u postgres psql -tAc "SELECT rolsuper FROM pg_roles WHERE rolname='webapp_user'" 2>/dev/null || true)
if [ "$IS_SUPER" = "f" ]; then
  pass "Role webapp_user is NOT a superuser (rolsuper = false)"
else
  fail "Role webapp_user has superuser privileges!"
fi

# 8. Sprawdzenie istnienia tabeli messages w webapp_db
TABLE_EXISTS=$(sudo -u postgres psql -d webapp_db -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='messages'" 2>/dev/null || true)
if [ "$TABLE_EXISTS" = "1" ]; then
  pass "Table messages exists in webapp_db"
else
  fail "Table messages does not exist in webapp_db"
fi

# 9. Sprawdzenie algorytmu szyfrowania hasel SCRAM-SHA-256
ENC=$(sudo -u postgres psql -tAc "SELECT setting FROM pg_settings WHERE name='password_encryption'" 2>/dev/null || true)
if [ "$ENC" = "scram-sha-256" ]; then
  pass "Password encryption algorithm is scram-sha-256"
else
  fail "Password encryption is $ENC (expected scram-sha-256)"
fi

# 10. Sprawdzenie reguly dla APP-SRV (192.168.20.10) w pg_hba.conf
HBA_RULE=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_hba_file_rules WHERE 'webapp_user' = ANY(user_name) AND 'webapp_db' = ANY(database) AND address='192.168.20.10' AND auth_method='scram-sha-256'" 2>/dev/null || true)
if [ "$HBA_RULE" = "1" ]; then
  pass "pg_hba.conf allows APP-SRV (192.168.20.10/32) using scram-sha-256"
else
  fail "Missing or invalid pg_hba.conf rule for APP-SRV"
fi

# 11. Sprawdzenie logowania polaczen i rozlaczen
LOG_CONN=$(sudo -u postgres psql -tAc "SELECT setting FROM pg_settings WHERE name='log_connections'" 2>/dev/null || true)
LOG_DISC=$(sudo -u postgres psql -tAc "SELECT setting FROM pg_settings WHERE name='log_disconnections'" 2>/dev/null || true)
if [ "$LOG_CONN" = "on" ] && [ "$LOG_DISC" = "on" ]; then
  pass "Connection and disconnection logging is enabled (log_connections=on, log_disconnections=on)"
else
  fail "Incomplete connection logging (log_connections=$LOG_CONN, log_disconnections=$LOG_DISC)"
fi

# 12. Testy operacyjne jako webapp_user (INSERT, SELECT, brak nadmiarowych praw)
PASSWORD="${DB_PASSWORD:-${PGPASSWORD:-}}"
if [ -n "$PASSWORD" ]; then
  TEST_MSG="Autotest-$(date +%s)"
  INS_RES=$(PGPASSWORD="$PASSWORD" psql -h 127.0.0.1 -U webapp_user -d webapp_db -tAc "INSERT INTO messages (content) VALUES ('$TEST_MSG') RETURNING id;" 2>/dev/null || true)
  INS_ID=$(echo "$INS_RES" | head -n 1)
  if [ -n "$INS_ID" ]; then
    pass "INSERT operation by webapp_user succeeded (id: $INS_ID)"
  else
    fail "INSERT operation by webapp_user failed"
  fi

  SEL_RES=$(PGPASSWORD="$PASSWORD" psql -h 127.0.0.1 -U webapp_user -d webapp_db -tAc "SELECT count(*) FROM messages WHERE content='$TEST_MSG';" 2>/dev/null || true)
  if [ "$SEL_RES" = "1" ]; then
    pass "SELECT operation by webapp_user succeeded"
  else
    fail "SELECT operation by webapp_user failed"
  fi

  if PGPASSWORD="$PASSWORD" psql -h 127.0.0.1 -U webapp_user -d webapp_db -c "CREATE TABLE probe_forbidden (id int);" 2>&1 | grep -q "permission denied"; then
    pass "Privilege restriction verified (CREATE TABLE denied in schema public)"
  else
    fail "Privilege escalation: webapp_user was able to CREATE TABLE!"
  fi
else
  skip "Operational tests for webapp_user skipped (DB_PASSWORD not set)"
fi

echo "======================================================"
echo " Database tests summary: PASS=$PASS, FAIL=$FAIL, SKIP=$SKIP"
echo "======================================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
