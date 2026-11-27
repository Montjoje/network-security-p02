#!/bin/bash
. /usr/local/lib/p02/lib.sh
log "APP-SRV: start"
cfg_if eth0 192.168.20.10/24
set_gw 192.168.20.1
add_host 192.168.20.10 app-srv secure-app.lab

# blokada SSH (host-based): tcp/22 DROP + licznik
nft -f /etc/nftables.conf && log "nftables: tcp/22 DROP aktywne"

# certyfikat X.509 (RSA 4096 + SAN), generowany przy pierwszym starcie
install -d -m 700 /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/secure-app.key ]; then
    openssl req -x509 -nodes -newkey rsa:4096 -days 365 \
        -keyout /etc/nginx/ssl/secure-app.key -out /etc/nginx/ssl/secure-app.crt \
        -subj "/C=PL/ST=Mazowieckie/L=Warsaw/O=P02-Lab/CN=secure-app.lab" \
        -addext "subjectAltName=DNS:secure-app.lab,IP:192.168.20.10" 2>/dev/null
    chmod 600 /etc/nginx/ssl/secure-app.key
    log "wygenerowano certyfikat"
fi

# log audytowy ModSecurity
touch /var/log/modsec_audit.log
chown www-data:adm /var/log/modsec_audit.log
chmod 640 /var/log/modsec_audit.log

# aplikacja Flask (gunicorn, uzytkownik bez uprawnien, tylko 127.0.0.1:5000)
install -d -o appuser -g appuser /var/log/app
runuser -u appuser -- env \
    DB_HOST="${DB_HOST:-192.168.30.10}" DB_PORT="${DB_PORT:-5432}" \
    DB_NAME="${DB_NAME:-webapp_db}" DB_USER="${DB_USER:-webapp_user}" \
    DB_PASSWORD="${DB_PASSWORD:-$LAB_DB_PASSWORD_DEFAULT}" \
    gunicorn --daemon --bind 127.0.0.1:5000 --chdir /opt/app \
        --access-logfile /var/log/app/access.log --error-logfile /var/log/app/error.log app:app
log "aplikacja uruchomiona (gunicorn 127.0.0.1:5000)"

# Nginx: TLS 1.3 + ModSecurity + OWASP CRS
if nginx -t 2>/tmp/nginx-test.log; then
    nginx && log "nginx uruchomiony (tcp/443, TLS 1.3, WAF)"
else
    log "BLAD: nginx -t"; cat /tmp/nginx-test.log
fi
log "APP-SRV gotowy"
console
