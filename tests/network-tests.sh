#!/bin/sh

ROLE="${1:-}"
CLIENT_IP="${CLIENT_IP:-192.168.10.10}"
PASS=0
FAIL=0

ok() {
    printf 'PASS: %s\n' "$1"
    PASS=$((PASS + 1))
}

bad() {
    printf 'FAIL: %s\n' "$1"
    FAIL=$((FAIL + 1))
}

check_local() {
    address="$1"
    gateway="$2"

    if ip -4 -o addr show | grep -q "inet $address/"; then
        ok "adres lokalny $address"
    else
        bad "brak adresu lokalnego $address"
    fi

    if ip route show default | grep -q "via $gateway "; then
        ok "brama domyślna $gateway"
    else
        bad "brak bramy domyślnej $gateway"
    fi
}

check_ping() {
    name="$1"
    address="$2"

    if ping -c 1 -W 2 "$address" >/dev/null 2>&1; then
        ok "routing/ping do $name ($address)"
    else
        bad "brak ping do $name ($address)"
    fi
}

check_open() {
    name="$1"
    address="$2"
    port="$3"

    if nc -z -w 3 "$address" "$port" >/dev/null 2>&1; then
        ok "$name TCP/$port dostępny"
    else
        bad "$name TCP/$port niedostępny (sprawdź, czy usługa nasłuchuje)"
    fi
}

check_blocked() {
    name="$1"
    address="$2"
    port="$3"

    if nc -z -w 3 "$address" "$port" >/dev/null 2>&1; then
        bad "$name TCP/$port jest dostępny, powinien być blokowany"
    else
        ok "$name TCP/$port nieosiągalny"
    fi
}

case "$ROLE" in
    client)
        check_local "$CLIENT_IP" "192.168.10.1"
        check_ping "APP-SRV" "192.168.20.10"
        check_ping "DB-SRV" "192.168.30.10"
        check_open "APP-SRV" "192.168.20.10" 443
        check_blocked "APP-SRV" "192.168.20.10" 80
        check_blocked "APP-SRV" "192.168.20.10" 22
        check_blocked "DB-SRV" "192.168.30.10" 5432
        ;;
    app)
        check_local "192.168.20.10" "192.168.20.1"
        check_ping "DB-SRV" "192.168.30.10"
        check_open "DB-SRV" "192.168.30.10" 5432
        ;;
    db)
        check_local "192.168.30.10" "192.168.30.1"
        ;;
    *)
        echo "Użycie: $0 {client|app|db}"
        exit 2
        ;;
esac

printf '\nPodsumowanie: PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
