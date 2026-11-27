#!/bin/bash
# Wspolne funkcje obrazow labu P02 (wezly Docker w GNS3).
# Plik jest wczytywany przez entrypoint.sh kazdego obrazu.

# Haslo konta aplikacji w bazie - TYLKO do laboratorium (identyczne w db-srv i app-srv).
LAB_DB_PASSWORD_DEFAULT='P02-lab-Passw0rd'

log() { echo "[p02-lab] $*"; }

# Czeka, az GNS3 doda interfejs sieciowy do kontenera (eth0, eth1, ...).
wait_iface() {
    local n=0
    until [ -e "/sys/class/net/$1" ]; do
        sleep 1
        n=$((n + 1))
        if [ "$n" -ge "${LAB_IFACE_TIMEOUT:-300}" ]; then
            log "BLAD: interfejs $1 nie pojawil sie w kontenerze"
            return 1
        fi
    done
}

# cfg_if <interfejs> <adres/maska>
cfg_if() {
    wait_iface "$1" || return 1
    ip link set "$1" up
    ip addr flush dev "$1"
    ip addr add "$2" dev "$1"
    log "$1 = $2"
}

# set_gw <adres bramy>
set_gw() { ip route replace default via "$1" && log "brama domyslna = $1"; }

# dopisuje wpis do /etc/hosts tylko raz
add_host() { grep -q "[[:space:]]$2\$" /etc/hosts 2>/dev/null || echo "$1 $2 ${3:-}" >> /etc/hosts; }

# Konsola dla GNS3 (telnet): proces glowny musi byc interaktywna powloka.
console() {
    if [ -t 0 ]; then
        exec /bin/bash -i
    else
        exec sleep infinity
    fi
}
