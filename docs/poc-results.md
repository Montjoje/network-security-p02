# Wyniki pełnych testów bezpieczeństwa PoC (Issue #21)

Skrypt: `tests/poc-tests.sh` (tryb `client` na CLIENT, tryb `app` na APP-SRV).
Logi: `docs/logs/poc/`, zrzuty ekranu: `docs/screenshots/poc/`.

Środowisko: kopia laboratorium w VirtualBox 7.1.4 (CLIENT-NET 192.168.10.0/24, DMZ 192.168.20.0/24, DB-NET 192.168.30.0/24), data 2026-11-26. Stan: APP-SRV po `waf/setup-app-srv.sh --lock-ssh`, DB-SRV po `scripts/configure-db.sh`. Testy wykonano przed restartem oraz po restarcie obu serwerów.
Zakres: w kopii nie ma filtrowania na routerze (zakres Osoby 3), więc zakaz klient → DB-SRV egzekwuje firewall DB-SRV. Test do powtórzenia w oficjalnym labie GNS3.

| Nr | Test | Wynik | Dowód | Interpretacja |
|---:|---|---|---|---|
| 1 | Normalne HTTPS działa | PASS (przed i po restarcie) | `poc-client-*.log` [1] | `GET /` przez HTTPS zwraca HTTP 200, więc Nginx i aplikacja odpowiadają klientowi. |
| 2 | TLS 1.3 działa | PASS | `poc-client-*.log` [2] (`TLS_AES_256_GCM_SHA384`) | Połączenie negocjuje TLS 1.3, zgodnie z wymaganiem. |
| 3 | TLS 1.2 jest odrzucany | PASS | `poc-client-*.log` [3] | Serwer odrzuca handshake TLS 1.2, więc słabsze wersje protokołu nie są dostępne. |
| 4 | SSH do APP-SRV jest zablokowane | PASS | `poc-client-*.log` [4]; `poc-app-wyniki.log` [4]; zrzuty 01–03 | Port 22 jest niedostępny z klienta, usługa SSH jest wyłączona, a nftables ma regułę `tcp dport 22 drop`. |
| 5 | Poprawny POST działa | PASS (id 5, po restarcie id 7) | `poc-client-*.log` [5] | Poprawne żądanie kończy się HTTP 201 i zapisem rekordu w bazie. |
| 6 | SQL Injection zwraca 403 | PASS | `poc-client-*.log` [6] | WAF blokuje ładunek SQLi, zanim dotrze do aplikacji. |
| 7 | Path Traversal zwraca 403 | PASS | `poc-client-*.log` [7] | WAF blokuje próbę odczytu plików spoza katalogu aplikacji. |
| 8 | Command Injection znajduje się w logu | PASS | `poc-app-wyniki.log` [8]; zrzuty 01, 02 | Żądanie ze znacznikiem testu jest w logu ModSecurity (reguła 100003), a aplikacja nie wykonuje polecenia (`executed:false`). |
| 9 | Klient nie łączy się z DB | PASS | `poc-client-*.log` [9] | Z klienta nie da się połączyć z `192.168.30.10:5432`, więc baza jest osiągalna tylko z APP-SRV. |
| 10 | APP-SRV łączy się z DB | PASS | `poc-app-wyniki.log` [10] (zapis id 6, po restarcie id 8) | APP-SRV łączy się z bazą na DB-SRV i zapisuje w niej rekordy. |
| 11 | Konfiguracja działa po restarcie | PASS | `poc-client-po-restarcie.log`; `poc-app-wyniki.log` (po restarcie); zrzut 02 | Po restarcie wszystkie usługi (docker, nginx, nftables, kontener) wstają same, a komplet testów przechodzi ponownie. |

Uwaga: podczas jednego z restartów APP-SRV system gościa zgłosił `Kernel panic` w pierwszych sekundach startu (awaria maszyny wirtualnej, nie projektu). Po ponownym uruchomieniu maszyna działała poprawnie i testy przeszły.
