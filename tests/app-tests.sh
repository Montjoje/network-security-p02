#!/usr/bin/env bash
# Testy funkcjonalne aplikacji P02.
# Testy atakow (SQLi, Path Traversal, Command Injection) sa w tests/tls-waf-tests.sh.
# Uzycie: ./tests/app-tests.sh http://127.0.0.1:5000

set -u

BASE_URL="${1:-}"
if [ -z "$BASE_URL" ]; then
  echo "Uzycie: $0 ADRES_APLIKACJI (np. http://127.0.0.1:5000)" >&2
  exit 2
fi
BASE_URL="${BASE_URL%/}"

TIMEOUT=10
PASS=0
FAIL=0
SKIP=0
RUN_ID="$(date +%s)-$$"   # unikalny znacznik danych testowych

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

echo "== Testy aplikacji: $BASE_URL (run $RUN_ID) =="

# --- GET / ---
http_request GET "/"
check_status   "GET / zwraca 200" 200
check_json     "GET / zwraca JSON"
check_contains "GET / zawiera status ok" '"status":"ok"'

# --- POST /message (formularz) ---
MESSAGE="test-form-$RUN_ID"
http_request POST "/message" -d "content=$MESSAGE"
check_status   "POST /message (formularz) zwraca 201" 201
check_json     "POST /message (formularz) zwraca JSON"
check_contains "POST /message (formularz) potwierdza zapis" '"status":"saved"'

# --- POST /message (JSON) ---
MESSAGE_JSON="test-json-$RUN_ID"
http_request POST "/message" -H "Content-Type: application/json" \
  -d "{\"content\":\"$MESSAGE_JSON\"}"
check_status "POST /message (JSON) zwraca 201" 201

# --- POST /message (puste dane) ---
http_request POST "/message" -d "content="
check_status "POST /message z pustym polem zwraca 400" 400

# --- GET /file ---
http_request GET "/file?name=example.txt"
check_status   "GET /file dla example.txt zwraca 200" 200
check_contains "GET /file zwraca tresc pliku" "P02"

# --- GET /command ---
http_request GET "/command?cmd=hello"
check_status   "GET /command zwraca 200" 200
check_contains "GET /command nie wykonuje polecenia" '"executed":false'

# --- nieistniejacy endpoint ---
http_request GET "/nie-istnieje-$RUN_ID"
check_status "Nieistniejacy endpoint zwraca 404" 404

echo "== Wynik: PASS=$PASS FAIL=$FAIL SKIP=$SKIP =="
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0