#!/usr/bin/env bash
# Testy funkcjonalne aplikacji P02.
# Testy atakow (SQLi, Path Traversal, Command Injection) sa w tests/tls-waf-tests.sh.
# Uzycie: ./tests/app-tests.sh http://127.0.0.1:5000
#
# Testy bazy, kontenerow i restartu wymagaja dzialajacego lokalnego Docker Compose
# (app/compose.local.yaml). Gdy go nie ma, odpowiednie testy dostaja status SKIP.
# Dane dostepowe do bazy nie sa potrzebne: psql dziala wewnatrz kontenera bazy.

set -u

BASE_URL="${1:-}"
if [ -z "$BASE_URL" ]; then
  echo "Uzycie: $0 ADRES_APLIKACJI (np. http://127.0.0.1:5000)" >&2
  exit 2
fi
BASE_URL="${BASE_URL%/}"

TIMEOUT=10
WAIT_SECONDS=60
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${APP_COMPOSE_DIR:-$SCRIPT_DIR/../app}"
COMPOSE_FILE_NAME="compose.local.yaml"

PASS=0
FAIL=0
SKIP=0
HAVE_DOCKER=0
RUN_ID=""

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP + 1)); }

# http_request METODA SCIEZKA [argumenty curl...]
# Ustawia: HTTP_CODE, HTTP_TYPE, HTTP_BODY
http_request() {
  local method="$1" path="$2"
  shift 2
  local out
  if ! out="$(curl -sS --max-time "$TIMEOUT" -X "$method" \
        -w $'\n%{http_code}\n%{content_type}' "$@" "${BASE_URL}${path}" 2>/dev/null)"; then
    HTTP_CODE="000"; HTTP_TYPE=""; HTTP_BODY=""
    return 1
  fi
  HTTP_TYPE="${out##*$'\n'}"
  out="${out%$'\n'*}"
  HTTP_CODE="${out##*$'\n'}"
  HTTP_BODY="${out%$'\n'*}"
}

check_status() {  # opis oczekiwany_kod
  if [ "$HTTP_CODE" = "$2" ]; then
    pass "$1 (HTTP $HTTP_CODE)"
  else
    fail "$1 (oczekiwano $2, otrzymano $HTTP_CODE)"
  fi
}

check_json() {  # opis
  case "$HTTP_TYPE" in
    application/json*) pass "$1" ;;
    *) fail "$1 (Content-Type: '$HTTP_TYPE')" ;;
  esac
}

check_contains() {  # opis fragment
  case "$HTTP_BODY" in
    *"$2"*) pass "$1" ;;
    *) fail "$1 (brak fragmentu '$2' w odpowiedzi)" ;;
  esac
}

# --- Docker Compose (tylko dla lokalnego srodowiska) ---
compose() {
  ( cd "$COMPOSE_DIR" && docker compose -f "$COMPOSE_FILE_NAME" "$@" )
}

running_services() {
  compose ps --status running --services 2>/dev/null | tr -d '\r'
}

detect_docker() {
  HAVE_DOCKER=0
  command -v docker >/dev/null 2>&1 || return 0
  [ -f "$COMPOSE_DIR/$COMPOSE_FILE_NAME" ] || return 0
  if [ -n "$(running_services)" ]; then
    HAVE_DOCKER=1
  fi
  return 0
}

# Liczba rekordow o danej tresci (psql wewnatrz kontenera bazy)
db_count() {  # tresc
  compose exec -T db sh -c \
    "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -tAc \"SELECT count(*) FROM messages WHERE content = '$1'\"" 2>/dev/null
}

check_saved() {  # opis tresc
  local n
  n="$(db_count "$2" | tr -d '[:space:]')"
  if [ "$n" = "1" ]; then
    pass "$1"
  else
    fail "$1 (liczba rekordow: '${n:-brak}')"
  fi
}

run_environment_checks() {
  echo "-- Srodowisko kontenerow --"
  if [ "$HAVE_DOCKER" != 1 ]; then
    skip "Status kontenerow (brak lokalnego Docker Compose)"
    skip "Port aplikacji nie jest publicznie wystawiony (brak lokalnego Docker Compose)"
    return
  fi
  local services svc bind
  services="$(running_services)"
  for svc in app db; do
    if printf '%s\n' "$services" | grep -qx "$svc"; then
      pass "Kontener $svc dziala"
    else
      fail "Kontener $svc nie dziala"
    fi
  done
  bind="$(compose port app 5000 2>/dev/null | tr -d '\r')"
  case "$bind" in
    127.0.0.1:*|"") pass "Port aplikacji nie jest publicznie wystawiony (${bind:-nieopublikowany})" ;;
    *) fail "Port aplikacji jest wystawiony publicznie ($bind)" ;;
  esac
}

run_functional_tests() {  # etykieta
  RUN_ID="$(date +%s)-$$"   # unikalny znacznik danych testowych
  echo "-- Testy funkcjonalne: $1 (run $RUN_ID) --"

  # GET /
  http_request GET "/"
  check_status   "GET / zwraca 200" 200
  check_json     "GET / zwraca JSON"
  check_contains "GET / zawiera status ok" '"status":"ok"'

  # POST /message (formularz)
  local message="test-form-$RUN_ID"
  http_request POST "/message" -d "content=$message"
  check_status   "POST /message (formularz) zwraca 201" 201
  check_json     "POST /message (formularz) zwraca JSON"
  check_contains "POST /message (formularz) potwierdza zapis" '"status":"saved"'

  # POST /message (JSON)
  local message_json="test-json-$RUN_ID"
  http_request POST "/message" -H "Content-Type: application/json" \
    -d "{\"content\":\"$message_json\"}"
  check_status "POST /message (JSON) zwraca 201" 201

  # POST /message (puste dane)
  http_request POST "/message" -d "content="
  check_status "POST /message z pustym polem zwraca 400" 400

  # GET /file
  http_request GET "/file?name=example.txt"
  check_status   "GET /file dla example.txt zwraca 200" 200
  check_contains "GET /file zwraca tresc pliku" "P02"

  # GET /command
  http_request GET "/command?cmd=hello"
  check_status   "GET /command zwraca 200" 200
  check_contains "GET /command nie wykonuje polecenia" '"executed":false'

  # nieistniejacy endpoint
  http_request GET "/nie-istnieje-$RUN_ID"
  check_status "Nieistniejacy endpoint zwraca 404" 404

  # zapis w bazie PostgreSQL
  if [ "$HAVE_DOCKER" = 1 ]; then
    check_saved "Wiadomosc z formularza zapisana w PostgreSQL" "$message"
    check_saved "Wiadomosc z JSON zapisana w PostgreSQL" "$message_json"
  else
    skip "Zapis wiadomosci w PostgreSQL (brak lokalnego Docker Compose)"
    skip "Zapis wiadomosci JSON w PostgreSQL (brak lokalnego Docker Compose)"
  fi
}

wait_for_app() {
  local waited=0
  echo "Czekam na aplikacje po restarcie (maks. ${WAIT_SECONDS}s)..."
  while [ "$waited" -lt "$WAIT_SECONDS" ]; do
    http_request GET "/"
    if [ "$HTTP_CODE" = "200" ]; then
      pass "Aplikacja odpowiada po restarcie"
      return
    fi
    sleep 2
    waited=$((waited + 2))
  done
  fail "Aplikacja nie odpowiada po restarcie (limit ${WAIT_SECONDS}s)"
}

echo "== Testy aplikacji: $BASE_URL =="

detect_docker
run_environment_checks
run_functional_tests "przed restartem"

echo "-- Restart aplikacji --"
if [ "$HAVE_DOCKER" != 1 ]; then
  skip "Restart aplikacji i powtorzenie testow (brak lokalnego Docker Compose)"
elif [ "$FAIL" -ne 0 ]; then
  skip "Restart aplikacji i powtorzenie testow (wczesniejsze testy nie przeszly)"
else
  if compose restart app >/dev/null 2>&1; then
    pass "Restart kontenera app"
    wait_for_app
    run_functional_tests "po restarcie"
  else
    fail "Restart kontenera app"
  fi
fi

echo "== Wynik: PASS=$PASS FAIL=$FAIL SKIP=$SKIP =="
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0