# Oczekiwane wyniki testów TLS 1.3 i WAF

Dokument opisuje oczekiwane rezultaty uruchamiania skryptu `tests/tls-waf-tests.sh` wobec hosta `APP-SRV` (`192.168.20.10`).

## Uruchomienie
```bash
./tests/tls-waf-tests.sh 192.168.20.10
```

## Tabela wyników

| Nr | Test | Oczekiwany wynik |
|---|---|---|
| 1 | Dostępność HTTPS (`GET /`) | `HTTP 200`, JSON zawiera `"status":"ok"` |
| 2 | Połączenie TLS 1.3 (`openssl -tls1_3`) | Połączenie nawiązane, protokół `TLSv1.3` |
| 3 | Odrzucenie TLS 1.2 (`openssl -tls1_2`) | Połączenie odrzucone (`alert protocol version` / brak szyfru) |
| 4 | Certyfikat X.509 | Zawiera SAN: `DNS:secure-app.lab` oraz `IP:192.168.20.10` |
| 5 | Poprawne `GET /file?name=example.txt` | `HTTP 200` |
| 6 | Poprawne `POST /message` | `HTTP 201` |
| 7 | SQL Injection w `POST /message` (`'OR 2>1--`) | `HTTP 403 Forbidden` + wpis w `/var/log/modsec_audit.log` |
| 8 | Path Traversal w `GET /file` (`../../../../../etc/passwd`) | `HTTP 403 Forbidden` + wpis w `/var/log/modsec_audit.log` |
| 9 | Command Injection w `GET /command` (`ls -la`) | `HTTP 200` z `"executed":false` (lub `403` nie jest błędem), polecenie niewykonane + wpis w `/var/log/modsec_audit.log` |
| 10 | Log audytowy ModSecurity | Zawiera wpisy dla SQL Injection, Path Traversal i Command Injection (`SKIP` przy uruchomieniu z klienta) |
| 11 | Konfiguracja i status Nginx | `nginx -t` poprawne, usługa `nginx` aktywna (`SKIP` przy uruchomieniu bez `sudo` na `APP-SRV`) |

## Ręczna weryfikacja na `APP-SRV`
```bash
sudo grep -i "SQL Injection" /var/log/modsec_audit.log
sudo grep -i "Path Traversal" /var/log/modsec_audit.log
sudo grep -i "Command Injection" /var/log/modsec_audit.log
sudo nginx -t && sudo systemctl is-active nginx
```