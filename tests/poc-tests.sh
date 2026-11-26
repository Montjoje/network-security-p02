#!/usr/bin/env bash
# =====================================================================
# P02: Pelne testy bezpieczenstwa PoC (Issue #21)
#
# Tryb "client" (uruchamiany na CLIENT, 192.168.10.10):
#   bash tests/poc-tests.sh client [APP_IP] [DB_IP]
#   testy: HTTPS, TLS 1.3, TLS 1.2, SSH do APP-SRV, POST, SQLi,
#          Path Traversal, Command Injection (wyslanie), klient -> DB
#
# Tryb "app" (uruchamiany na APP-SRV, wymaga sudo):
#   sudo bash tests/poc-tests.sh app [APP_IP] [DB_IP] [ZNACZNIK]
#   testy: Command Injection w logu ModSecurity, APP-SRV -> DB,
#          kontener aplikacji, uslugi po restarcie
#   ZNACZNIK = wartosc "MARKER=..." wypisana przez tryb client
#
# Wynik: PASS/FAIL, kod wyjscia 1 gdy jest FAIL.
# =====================================================================
set -u

MODE="${1:-client}"
APP_IP="${2:-192.168.20.10}"
DB_IP="${3:-192.168.30.10}"
MARKER_ARG="${4:-}"
BASE_URL="https://${APP_IP}"
AUDIT_LOG="/var/log/modsec_audit.log"
CT=5
MT=10

PASS=0; FAIL=0
pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# zwraca 0, gdy polaczenie TCP sie udalo
tcp_open() { timeout "$CT" bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

code() { # code <curl args...> -> HTTP code
  local r
  r=$(curl -k -sS --tlsv1.3 --connect-timeout "$CT" --max-time "$MT" -o "$TMP" -w "%{http_code}" "$@" 2>/dev/null)
  echo "${r:-000}"
}

client_tests() {
  local c out reach=0

  echo "[1] Normalne HTTPS"
  # pierwsze zadanie po starcie maszyn bywa wolne: do 3 prob
  for attempt in 1 2 3; do
    c=$(code "${BASE_URL}/")
    [[ "$c" == "200" ]] && break
    [[ "$attempt" -lt 3 ]] && { echo "     proba ${attempt}: HTTP ${c}, ponawiam..."; sleep 5; }
  done
  [[ "$c" == "200" ]] && reach=1
  [[ "$c" == "200" ]] && grep -q '"status"' "$TMP" \
    && pass "GET / przez HTTPS -> HTTP 200" || fail "GET / -> HTTP ${c} (oczekiwano 200)"

  echo "[2] TLS 1.3"
  out=$(timeout "$CT" openssl s_client -connect "${APP_IP}:443" -tls1_3 </dev/null 2>&1 || true)
  echo "$out" | grep -q "TLSv1.3" && echo "$out" | grep -Eq "Cipher is TLS_|Cipher[[:space:]]*:[[:space:]]*TLS_" \
    && pass "Polaczenie TLS 1.3 nawiazane ($(echo "$out" | grep -Eo 'TLS_[A-Z0-9_]+' | head -1))" \
    || fail "Nie nawiazano polaczenia TLS 1.3"

  echo "[3] TLS 1.2 odrzucany"
  out=$(timeout "$CT" openssl s_client -connect "${APP_IP}:443" -tls1_2 </dev/null 2>&1 || true)
  echo "$out" | grep -Eq "alert protocol version|Cipher is \(NONE\)|Cipher[[:space:]]*:[[:space:]]*0000|handshake failure|no protocols available" \
    && pass "TLS 1.2 odrzucony" || fail "TLS 1.2 nie zostal odrzucony"

  echo "[4] SSH do APP-SRV zablokowane"
  if tcp_open "$APP_IP" 22; then
    fail "Port 22 na APP-SRV jest osiagalny z klienta"
  elif [[ "$reach" -ne 1 ]]; then
    fail "Port 22 niedostepny, ale APP-SRV w ogole nie odpowiada na 443 (wynik niewiarygodny)"
  else
    pass "Port 22 na APP-SRV niedostepny z klienta (timeout/odrzucenie)"
  fi

  echo "[5] Poprawny POST"
  c=$(code -X POST "${BASE_URL}/message" --data-urlencode "content=PoC poprawny POST $(date +%s)")
  [[ "$c" == "201" ]] && pass "POST /message -> HTTP 201: $(cat "$TMP")" || fail "POST /message -> HTTP ${c} (oczekiwano 201)"

  echo "[6] SQL Injection"
  c=$(code -X POST "${BASE_URL}/message" --data-urlencode "username=admin" --data-urlencode "content='OR 2>1--")
  [[ "$c" == "403" ]] && pass "SQL Injection -> HTTP 403" || fail "SQL Injection -> HTTP ${c} (oczekiwano 403)"

  echo "[7] Path Traversal"
  c=$(code --get "${BASE_URL}/file" --data-urlencode "name=../../../../../etc/passwd")
  [[ "$c" == "403" ]] && pass "Path Traversal -> HTTP 403" || fail "Path Traversal -> HTTP ${c} (oczekiwano 403)"

  echo "[8] Command Injection (wyslanie; wpis w logu sprawdza tryb app)"
  local marker="poc$(date +%s)"
  c=$(code --get "${BASE_URL}/command" --data-urlencode "cmd=ls -la ${marker}")
  if [[ "$c" == "403" ]] || { [[ "$c" == "200" ]] && grep -Eq '"executed"[[:space:]]*:[[:space:]]*false' "$TMP"; }; then
    pass "Command Injection obsluzone bez wykonania polecenia (HTTP ${c})"
  else
    fail "Command Injection -> nieoczekiwany wynik (HTTP ${c})"
  fi
  echo "MARKER=${marker}"

  echo "[9] Klient nie laczy sie z DB"
  if tcp_open "$DB_IP" 5432; then
    fail "Klient polaczyl sie z ${DB_IP}:5432"
  elif [[ "$reach" -ne 1 ]]; then
    fail "Brak polaczenia z DB, ale APP-SRV tez nie odpowiada (wynik niewiarygodny)"
  else
    pass "Klient nie polaczyl sie z ${DB_IP}:5432"
  fi
}

app_tests() {
  local out
  [[ "$(id -u)" -eq 0 ]] || { echo "Tryb app wymaga sudo"; exit 2; }

  echo "[8] Command Injection w logu"
  if [[ -n "$MARKER_ARG" ]]; then
    grep -q "$MARKER_ARG" "$AUDIT_LOG" 2>/dev/null \
      && pass "Log ${AUDIT_LOG} zawiera zadanie ze znacznikiem ${MARKER_ARG}" \
      || fail "Brak znacznika ${MARKER_ARG} w ${AUDIT_LOG}"
  fi
  grep -qi "Command Injection" "$AUDIT_LOG" 2>/dev/null \
    && pass "Log zawiera wpis Command Injection (regula 100003)" || fail "Brak wpisu Command Injection w logu"
  grep -qi "SQL Injection" "$AUDIT_LOG" 2>/dev/null && grep -qi "Path Traversal" "$AUDIT_LOG" 2>/dev/null \
    && pass "Log zawiera tez wpisy SQL Injection i Path Traversal" || fail "Brak wpisow SQL Injection / Path Traversal w logu"

  echo "[10] APP-SRV laczy sie z DB"
  tcp_open "$DB_IP" 5432 && pass "TCP APP-SRV -> ${DB_IP}:5432 dziala" || fail "APP-SRV nie laczy sie z ${DB_IP}:5432"
  out=$(docker ps --filter name=p02-lab-app --format '{{.Names}} {{.Status}}' 2>/dev/null)
  echo "$out" | grep -q "Up" && pass "Kontener aplikacji dziala: ${out}" || fail "Kontener aplikacji nie dziala"
  curl -sS --max-time "$MT" -X POST http://127.0.0.1:5000/message --data-urlencode "content=PoC zapis do DB-SRV $(date +%s)" -o "$TMP" -w "%{http_code}" 2>/dev/null | grep -q 201 \
    && pass "Aplikacja zapisuje rekord w DB-SRV: $(cat "$TMP")" || fail "Zapis z aplikacji do DB-SRV nie dziala"

  echo "[4] SSH zablokowane po stronie APP-SRV"
  if systemctl is-active --quiet ssh || systemctl is-active --quiet ssh.socket; then
    fail "Usluga SSH jest aktywna (uruchom: sudo waf/setup-app-srv.sh --lock-ssh)"
  else
    pass "Usluga SSH jest wylaczona"
  fi
  nft list table inet app_sec 2>/dev/null | grep -q "dport 22.*drop" \
    && pass "Regula nftables 'tcp dport 22 drop' jest aktywna" || fail "Brak aktywnej reguly nftables dla portu 22"

  echo "[11] Uslugi (uzyj po restarcie)"
  for s in docker nginx nftables; do
    systemctl is-active --quiet "$s" && pass "Usluga ${s} aktywna" || fail "Usluga ${s} nieaktywna"
  done
  nginx -t >/dev/null 2>&1 && pass "nginx -t poprawne" || fail "nginx -t zwraca blad"
}

echo "=========================================="
echo " P02 PoC: tryb=${MODE} APP=${APP_IP} DB=${DB_IP}"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
case "$MODE" in
  client) client_tests ;;
  app) app_tests ;;
  *) echo "Uzycie: $0 client|app [APP_IP] [DB_IP] [ZNACZNIK]"; exit 2 ;;
esac
echo "------------------------------------------"
echo "Podsumowanie: PASS=${PASS} FAIL=${FAIL}"
[[ "$FAIL" -eq 0 ]]
