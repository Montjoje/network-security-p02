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

---

## Wyniki w laboratorium GNS3 (węzły Docker)

Środowisko: GNS3 2.2.54 + GNS3 VM, projekt `p02-lab-docker` utworzony skryptem `lab/gns3/create-project.py`, obrazy z `lab/` (instrukcja: `lab/README.md`), data 2026-11-27. Topologia: CLIENT 192.168.10.10 ↔ Router ↔ APP-SRV 192.168.20.10 oraz DB-SRV 192.168.30.10, router z regułami `nftables` (forward = drop) zgodnymi z `network/traffic-matrix.md`. Wszystkie węzły to kontenery, więc lab działa bez KVM. Testy wykonano przed restartem i po restarcie wszystkich węzłów (Stop all / Start all w GNS3).
Logi: `docs/logs/poc/gns3-*.log`, zrzuty ekranu: `docs/screenshots/poc/gns3-*.png`.

Uproszczenia względem maszyn wirtualnych: aplikacja Flask działa w kontenerze APP-SRV razem z Nginx (bez Dockera w Dockerze), na APP-SRV nie działa żaden serwer SSH, a port 22 jest dodatkowo odrzucany regułą `nftables`; testy „usług” sprawdzają procesy zamiast jednostek systemd.

| Nr | Test | Wynik | Dowód | Interpretacja |
|---:|---|---|---|---|
| 1 | Normalne HTTPS działa | PASS (przed i po restarcie) | `gns3-poc-client-*.log` [1]; zrzuty 02, 05 | `GET /` przez HTTPS z CLIENT przechodzi przez router do APP-SRV i zwraca HTTP 200. |
| 2 | TLS 1.3 działa | PASS | `gns3-poc-client-*.log` [2] (`TLS_AES_256_GCM_SHA384`) | Połączenie negocjuje TLS 1.3, zgodnie z wymaganiem. |
| 3 | TLS 1.2 jest odrzucany | PASS | `gns3-poc-client-*.log` [3] | Serwer odrzuca handshake TLS 1.2. |
| 4 | SSH do APP-SRV jest zablokowane | PASS | `gns3-poc-client-*.log` [4]; `gns3-poc-app-*.log` [4]; `gns3-router-nft-*.log` (licznik reguły 22/80); zrzuty 04, 06 | Port 22 jest niedostępny z klienta, router odrzuca pakiety na 22/80 (licznik 3 pakiety), a na APP-SRV nie nasłuchuje SSH i działa reguła `tcp dport 22 drop`. |
| 5 | Poprawny POST działa | PASS (id 1, po restarcie id 35) | `gns3-poc-client-*.log` [5] | Poprawne żądanie kończy się HTTP 201 i zapisem w bazie na DB-SRV. |
| 6 | SQL Injection zwraca 403 | PASS | `gns3-poc-client-*.log` [6] | WAF blokuje ładunek SQLi. |
| 7 | Path Traversal zwraca 403 | PASS | `gns3-poc-client-*.log` [7] | WAF blokuje odczyt plików spoza katalogu aplikacji. |
| 8 | Command Injection znajduje się w logu | PASS | `gns3-poc-app-*.log` [8] (znaczniki `poc1795745630`, `poc1795745951`); zrzut 07 | Żądanie ze znacznikiem jest w logu ModSecurity (reguła 100003), polecenie nie jest wykonywane. |
| 9 | Klient nie łączy się z DB | PASS | `gns3-poc-client-*.log` [9]; `gns3-router-nft-*.log` (licznik reguły klient → DB: 3 pakiety) | Router odrzuca ruch klient → DB-SRV, więc baza jest osiągalna tylko z APP-SRV. |
| 10 | APP-SRV łączy się z DB | PASS | `gns3-poc-app-*.log` [10] (zapis id 2, po restarcie id 38); `gns3-router-nft-*.log` (licznik reguły 5432) | APP-SRV łączy się z bazą na DB-SRV przez router (reguła APP → DB TCP/5432) i zapisuje rekordy. |
| 11 | Konfiguracja działa po restarcie | PASS | `gns3-poc-client-po-restarcie.log`; `gns3-poc-app-po-restarcie.log`; `gns3-router-nft-po-restarcie.log`; zrzuty 05–07 | Po zatrzymaniu i uruchomieniu wszystkich węzłów usługi i reguły routera startują same, dane w bazie zostają (2 rekordy), a komplet testów przechodzi ponownie. |

Obserwacja: po restarcie identyfikator rekordu skoczył z 2 do 35. To normalne zachowanie sekwencji PostgreSQL po restarcie bez czystego zamknięcia (kontener jest zatrzymywany bez zatrzymania bazy); dane nie zostały utracone.
