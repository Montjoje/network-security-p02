#!/usr/bin/env bash
set -u

RAW_TARGET="${1:-192.168.20.10}"
HOST="${RAW_TARGET#https://}"
HOST="${HOST#http://}"
HOST="${HOST%%/*}"
HOST="${HOST%%:*}"
BASE_URL="https://${HOST}"

CONNECT_TIMEOUT=5
MAX_TIME=10
AUDIT_LOG="/var/log/modsec_audit.log"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY"' EXIT

pass() {
    echo "[PASS] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
    echo "[SKIP] $1"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

echo "=========================================="
echo " Testy TLS 1.3 i WAF dla: ${BASE_URL}"
echo "=========================================="

# 1. Dostepnosc HTTPS i poprawne GET /
http_code=$(curl -k -sS --tlsv1.3 --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
    -o "$TMP_BODY" -w "%{http_code}" "${BASE_URL}/" 2>/dev/null || echo "000")
if [[ "$http_code" == "200" ]] && grep -q '"status"' "$TMP_BODY"; then
    pass "HTTPS dostepne oraz poprawne GET / zwrocilo HTTP 200"
else
    fail "HTTPS / GET / zwrocilo HTTP ${http_code} (oczekiwano 200)"
fi

# 2. Potwierdzenie TLS 1.3
tls13_out=$(timeout "$CONNECT_TIMEOUT" openssl s_client -connect "${HOST}:443" -tls1_3 </dev/null 2>&1 || true)
if echo "$tls13_out" | grep -q "TLSv1.3" && echo "$tls13_out" | grep -Eq "Cipher is TLS_|Cipher[[:space:]]*:[[:space:]]*TLS_"; then
    pass "Polaczenie TLS 1.3 zostalo poprawnie nawiazane"
else
    fail "Nie udalo sie nawiazac polaczenia TLS 1.3"
fi

# 3. Potwierdzenie odrzucenia TLS 1.2
tls12_out=$(timeout "$CONNECT_TIMEOUT" openssl s_client -connect "${HOST}:443" -tls1_2 </dev/null 2>&1 || true)
if echo "$tls12_out" | grep -Eq "alert protocol version|Cipher is \(NONE\)|Cipher[[:space:]]*:[[:space:]]*0000|handshake failure|no protocols available"; then
    pass "Polaczenie TLS 1.2 zostalo poprawnie odrzucone"
else
    fail "Polaczenie TLS 1.2 nie zostalo odrzucone"
fi

# 4. Informacje o certyfikacie (CN + SAN)
cert_out=$(timeout "$CONNECT_TIMEOUT" openssl s_client -connect "${HOST}:443" -tls1_3 </dev/null 2>/dev/null \
    | openssl x509 -noout -subject -dates -ext subjectAltName 2>/dev/null || true)
if [[ -n "$cert_out" ]] && echo "$cert_out" | grep -q "secure-app.lab" && echo "$cert_out" | grep -q "192.168.20.10"; then
    pass "Certyfikat zawiera wymagane wpisy SAN (secure-app.lab oraz 192.168.20.10)"
else
    fail "Brak wymaganych danych certyfikatu lub SAN (secure-app.lab, 192.168.20.10)"
fi

# 5. Poprawne GET /file?name=example.txt
http_code=$(curl -k -sS --tlsv1.3 --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
    -o "$TMP_BODY" -w "%{http_code}" --get "${BASE_URL}/file" \
    --data-urlencode "name=example.txt" 2>/dev/null || echo "000")
if [[ "$http_code" == "200" ]]; then
    pass "Poprawne GET /file?name=example.txt zwrocilo HTTP 200"
else
    fail "Poprawne GET /file?name=example.txt zwrocilo HTTP ${http_code} (oczekiwano 200)"
fi

# 6. Poprawne POST /message
http_code=$(curl -k -sS --tlsv1.3 --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
    -o "$TMP_BODY" -w "%{http_code}" -X POST "${BASE_URL}/message" \
    --data-urlencode "content=Poprawna wiadomosc testowa" 2>/dev/null || echo "000")
if [[ "$http_code" == "201" ]]; then
    pass "Poprawne POST /message zwrocilo HTTP 201"
else
    fail "Poprawne POST /message zwrocilo HTTP ${http_code} (oczekiwano 201)"
fi

# 7. Blokowanie SQL Injection w POST
http_code=$(curl -k -sS --tlsv1.3 --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
    -o "$TMP_BODY" -w "%{http_code}" -X POST "${BASE_URL}/message" \
    --data-urlencode "username=admin" \
    --data-urlencode "content='OR 2>1--" 2>/dev/null || echo "000")
if [[ "$http_code" == "403" ]]; then
    pass "SQL Injection w POST zostalo zablokowane (HTTP 403)"
else
    fail "SQL Injection w POST zwrocilo HTTP ${http_code} (oczekiwano 403)"
fi

# 8. Blokowanie Path Traversal w GET
http_code=$(curl -k -sS --tlsv1.3 --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
    -o "$TMP_BODY" -w "%{http_code}" --get "${BASE_URL}/file" \
    --data-urlencode "name=../../../../../etc/passwd" 2>/dev/null || echo "000")
if [[ "$http_code" == "403" ]]; then
    pass "Path Traversal w GET zostalo zablokowane (HTTP 403)"
else
    fail "Path Traversal w GET zwrocilo HTTP ${http_code} (oczekiwano 403)"
fi

# 9. Command Injection w GET (brak 403 nie jest bledem; polecenie nie moze zostac wykonane)
http_code=$(curl -k -sS --tlsv1.3 --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
    -o "$TMP_BODY" -w "%{http_code}" --get "${BASE_URL}/command" \
    --data-urlencode "cmd=ls -la" 2>/dev/null || echo "000")
if [[ "$http_code" == "200" ]] && grep -Eq '"executed"[[:space:]]*:[[:space:]]*false' "$TMP_BODY"; then
    pass "Command Injection w GET obsluzone bez wykonania polecenia (HTTP 200, executed=false)"
elif [[ "$http_code" == "403" ]]; then
    pass "Command Injection w GET zablokowane przez WAF (HTTP 403)"
else
    fail "Command Injection w GET zwrocilo nieoczekiwany wynik (HTTP ${http_code})"
fi

# 10. Weryfikacja logu audytowego ModSecurity (lokalnie na APP-SRV)
if [[ -r "$AUDIT_LOG" ]]; then
    if grep -qi "SQL Injection" "$AUDIT_LOG" \
        && grep -qi "Path Traversal" "$AUDIT_LOG" \
        && grep -qi "Command Injection" "$AUDIT_LOG"; then
        pass "Log audytowy ${AUDIT_LOG} zawiera wpisy SQL Injection, Path Traversal i Command Injection"
    else
        fail "Brak wszystkich wymaganych wpisow w ${AUDIT_LOG}"
    fi
else
    skip "Brak lokalnego dostepu do ${AUDIT_LOG} (zweryfikuj recznie na APP-SRV)"
fi

# 11. Sprawdzenie konfiguracji i statusu Nginx (lokalnie na APP-SRV)
if command -v nginx >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
    if nginx -t >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
        pass "Konfiguracja Nginx jest poprawna (nginx -t) i usluga jest aktywna"
    else
        fail "Blad konfiguracji Nginx lub usluga nginx nie jest aktywna"
    fi
else
    skip "Sprawdzenie nginx -t i statusu uslugi wymaga uruchomienia z sudo na APP-SRV"
fi

echo "------------------------------------------"
echo "Podsumowanie: PASS=${PASS_COUNT}, FAIL=${FAIL_COUNT}, SKIP=${SKIP_COUNT}"
echo "------------------------------------------"
echo "Przypomnienie: sprawdz recznie logi i status na APP-SRV:"
echo "  sudo grep -i \"SQL Injection\" /var/log/modsec_audit.log"
echo "  sudo grep -i \"Path Traversal\" /var/log/modsec_audit.log"
echo "  sudo grep -i \"Command Injection\" /var/log/modsec_audit.log"
echo "  sudo nginx -t && sudo systemctl is-active nginx"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
exit 0
