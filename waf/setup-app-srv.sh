#!/usr/bin/env bash
set -euo pipefail

LOCK_SSH=false
if [[ "${1:-}" == "--lock-ssh" ]]; then
    LOCK_SSH=true
fi

if [[ "${EUID}" -ne 0 ]]; then
    echo "Błąd: uruchom skrypt jako root (np. sudo $0 [--lock-ssh])." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

REQUIRED_FILES=(
    "${REPO_DIR}/waf/nginx/secure-app.conf"
    "${REPO_DIR}/waf/modsecurity/main.conf"
    "${REPO_DIR}/waf/modsecurity/custom-rules.conf"
    "${REPO_DIR}/waf/nftables.conf"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "Błąd: brak wymaganego pliku w repozytorium: $f" >&2
        exit 1
    fi
done

echo "[1/7] Konfiguracja nazwy hosta i /etc/hosts..."
hostnamectl set-hostname app-srv
if ! grep -Eq '^[[:space:]]*192\.168\.20\.10[[:space:]]+.*secure-app\.lab' /etc/hosts; then
    echo "192.168.20.10 app-srv secure-app.lab" >> /etc/hosts
fi

echo "[2/7] Instalacja pakietów (Nginx, ModSecurity, OWASP CRS, nftables)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    nginx \
    libnginx-mod-http-modsecurity \
    modsecurity-crs \
    nftables \
    openssl \
    curl \
    git \
    ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    echo "[2b/7] Instalacja Docker (brak w obrazie bazowym)..."
    apt-get install -y docker.io docker-compose
    systemctl enable --now docker
fi

echo "[3/7] Generowanie certyfikatu X.509 (RSA 4096 + SAN)..."
install -d -m 700 -o root -g root /etc/nginx/ssl
if [[ ! -f /etc/nginx/ssl/secure-app.key || ! -f /etc/nginx/ssl/secure-app.crt ]]; then
    openssl req -x509 -nodes -newkey rsa:4096 -days 365 \
        -keyout /etc/nginx/ssl/secure-app.key \
        -out /etc/nginx/ssl/secure-app.crt \
        -subj "/C=PL/ST=Mazowieckie/L=Warsaw/O=P02-Lab/CN=secure-app.lab" \
        -addext "subjectAltName=DNS:secure-app.lab,IP:192.168.20.10"
fi
chown root:root /etc/nginx/ssl/secure-app.key /etc/nginx/ssl/secure-app.crt
chmod 600 /etc/nginx/ssl/secure-app.key
chmod 644 /etc/nginx/ssl/secure-app.crt

echo "[4/7] Wdrażanie konfiguracji Nginx, ModSecurity i nftables..."
install -d -m 755 /etc/modsecurity

install -m 644 "${REPO_DIR}/waf/nginx/secure-app.conf" /etc/nginx/sites-available/secure-app.conf
install -m 644 "${REPO_DIR}/waf/modsecurity/main.conf" /etc/modsecurity/main.conf
install -m 644 "${REPO_DIR}/waf/modsecurity/custom-rules.conf" /etc/modsecurity/custom-rules.conf
install -m 644 "${REPO_DIR}/waf/nftables.conf" /etc/nftables.conf

# Usunięcie ewentualnych końców linii CRLF (jeśli pliki były edytowane na Windowsie)
sed -i 's/\r$//' \
    /etc/nginx/sites-available/secure-app.conf \
    /etc/modsecurity/main.conf \
    /etc/modsecurity/custom-rules.conf \
    /etc/nftables.conf

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/secure-app.conf /etc/nginx/sites-enabled/secure-app.conf

echo "[5/7] Konfiguracja logu audytowego ModSecurity..."
touch /var/log/modsec_audit.log
chown www-data:adm /var/log/modsec_audit.log
chmod 640 /var/log/modsec_audit.log

echo "[6/7] Walidacja i uruchomienie Nginx..."
nginx -t
systemctl enable --now nginx
systemctl reload nginx

if [[ -f "${REPO_DIR}/tests/tls-waf-tests.sh" ]]; then
    install -m 700 "${REPO_DIR}/tests/tls-waf-tests.sh" /root/tls-waf-tests.sh
    sed -i 's/\r$//' /root/tls-waf-tests.sh
fi

echo "[7/7] Walidacja składni nftables..."
nft -c -f /etc/nftables.conf

if [[ "${LOCK_SSH}" == "true" ]]; then
    echo ">>> Blokowanie SSH i aktywacja nftables (TCP/22 DROP + LOG)..."
    systemctl disable --now ssh ssh.socket 2>/dev/null || true
    if systemctl is-active --quiet nftables; then
        nft delete table inet app_sec 2>/dev/null || true
        nft -f /etc/nftables.conf
    else
        systemctl enable --now nftables
    fi
    echo "GOTOWE: SSH wyłączone i zablokowane. Sprawdź: ss -lntp | grep 22 && nft list table inet app_sec"
else
    echo ""
    echo "GOTOWE (etap 1): Nginx + TLS 1.3 + ModSecurity + OWASP CRS działają."
    echo "UWAGA: SSH pozostało włączone, abyś mógł zbudować aplikację i spiąć DB-SRV."
    echo "Po zakończeniu prac uruchom Z LOKALNEJ KONSOLI VM:"
    echo "  sudo ${SCRIPT_DIR}/setup-app-srv.sh --lock-ssh"
fi