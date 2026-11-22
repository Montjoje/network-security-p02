# WAF i TLS (`APP-SRV`)

Konfiguracja reverse proxy Nginx z wymuszonym wyłącznie TLS 1.3 oraz host-based WAF (ModSecurity v3 + OWASP CRS + reguły dedykowane) dla projektu P02.

## Struktura plików
- `waf/nginx/secure-app.conf` — konfiguracja serwera HTTPS (TCP/443, wyłącznie `TLSv1.3`, reverse proxy do `[http://127.0.0.1:5000](http://127.0.0.1:5000)`, podpięty ModSecurity).
- `waf/modsecurity/main.conf` — główna konfiguracja ModSecurity (`SecRuleEngine On`, log audytowy `/var/log/modsec_audit.log`, ładowanie reguł własnych i OWASP CRS).
- `waf/modsecurity/custom-rules.conf` — dedykowane reguły projektu:
  - `id:100001` — blokowanie i logowanie SQL Injection w `POST` (`HTTP 403`),
  - `id:100002` — blokowanie i logowanie Path Traversal w `GET` (`HTTP 403`),
  - `id:100003` — wykrywanie i wyłączne logowanie Command Injection w `GET` (`pass`, `ctl:auditEngine=On`, `ctl:ruleEngine=DetectionOnly`).

## Wdrożenie na `APP-SRV` (Debian 13)
1. Zainstalować pakiety: `nginx`, `libnginx-mod-http-modsecurity`, `modsecurity-crs`.
2. Usunąć domyślny vhost `/etc/nginx/sites-enabled/default` (brak nasłuchu na TCP/80).
3. Wygenerować certyfikat laboratoryjny w `/etc/nginx/ssl/secure-app.crt` i klucz `/etc/nginx/ssl/secure-app.key` (`chmod 600`) z `subjectAltName=DNS:secure-app.lab,IP:192.168.20.10`.
4. Skopiować pliki z `waf/nginx/` do `/etc/nginx/sites-available/` (włączyć symlink w `sites-enabled`) oraz z `waf/modsecurity/` do `/etc/modsecurity/`.
5. Utworzyć `/var/log/modsec_audit.log` (`chown www-data:adm`, `chmod 640`).
6. Zweryfikować i przeładować: `sudo nginx -t && sudo systemctl reload nginx`.

## Testy
Automatyczna weryfikacja: `./tests/tls-waf-tests.sh 192.168.20.10` (szczegóły w `tests/expected-results.md`).