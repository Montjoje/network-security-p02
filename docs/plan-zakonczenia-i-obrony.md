# Plan dokończenia projektu P02 i przygotowanie do obrony

Dokument powstał na podstawie Issues w repozytorium, wymagań z treści tematu nr 2 (`docs/requirements.md`) i podziału ról z `docs/Instrukcja_AI_projekt_P02_4_osoby.md`. Stan: 2026-11-27. Terminów oddania i obrony nie ma w repozytorium, więc trzeba je ustalić w zespole.

## 1. Co jest oceniane

| Część | Punkty | Co dokładnie |
|---|---:|---|
| Projekt | 10 | raport z diagramem architektury, opisem zabezpieczeń i **uzasadnieniem** każdego z nich (Blueprint, Issue #24) |
| Raport z wdrożenia | 4 | opis stworzonej sieci i wdrożonych zabezpieczeń, potwierdzony logami i zrzutami (Issue #25) |
| Prezentacja na zajęciach | 5 | **demo na żywo** działającej bezpiecznej usługi WWW i dowody działania zabezpieczeń (Issue #26) |

Środowisko wg tematu to GNS3. Dozwolone alternatywy: Terraform na KVM lub Docker Swarm. Nasza wersja: GNS3 z węzłami Docker (`lab/`, opis w `docs/lab-gns3-docker.md`).

## 2. Stan Issues (2026-11-27)

| Obszar | Stan |
|---|---|
| APP (#6, #7, #30, #34), TLS/WAF/SSH (#8–#11, #29), NET (#13, #14, #28), DB (#15–#18, #27), integracja (#20, #21) | zamknięte |
| #1 `[APP] Przygotować szkielet aplikacji Flask` | otwarte, ale to duplikat zamkniętego #6 (aplikacja istnieje), do zamknięcia |
| #12 `[TEST] Testy APP, TLS i WAF` | otwarte; skrypty `tests/app-tests.sh` i `tests/tls-waf-tests.sh` są w repo (zamknięte #29 i #30), do sprawdzenia i zamknięcia |
| #19 `[TEST] Testy sieci i bazy danych` | otwarte; w repo jest `tests/database-tests.sh`, **brakuje `tests/network-tests.sh`** (skrypt `network-tests.sh` Osoby 3 istnieje w jego projekcie GNS3, ale nie ma go w repozytorium) |
| #22 `[EVIDENCE]` zrzuty i logi | otwarte; w `docs/screenshots/` są tylko `poc/` i `tls-waf/`, brakuje m.in. reguł nftables DB-SRV, adresu nasłuchu PostgreSQL, topologii |
| #23 `[HANDOVER]` | otwarte; **plik `HANDOVER.md` nie istnieje** |
| #24 `[DOC]` Blueprint | otwarte; jest tylko diagram (`docs/blueprint/architecture.drawio(.png)`), brakuje dokumentu |
| #25 `[DOC]` raport z wdrożenia | otwarte; brak dokumentu |
| #26 `[PRESENTATION]` | otwarte; brak slajdów i scenariusza demo |

## 3. Wspólne decyzje do podjęcia teraz

1. **Na czyim komputerze robimy demo.** Lab GNS3 musi działać na jednym komputerze na zajęciach. Zalecane: komputer, na którym lab działa bez problemów, i zrobić tam próbę generalną. Jeśli to komputer Osoby 1 (Windows, GNS3 VM, obrazy już zbudowane), reszta zespołu przygotowuje się do pokazywania z konsol.
2. **Czy nowy lab (węzły Docker) zastępuje topologię Alpine/Qemu Osoby 3.** Pliki Osoby 3 nie były zmieniane.
3. **Szyfrowanie APP-SRV → DB-SRV.** W konfiguracji PostgreSQL nie ma SSL, więc ta ścieżka nie jest szyfrowana. Albo dodajemy szyfrowanie, albo opisujemy to w Blueprincie i raporcie jako świadome ograniczenie (segment DB-NET, reguły routera, `pg_hba`).
4. **Zakres utwardzania DB-SRV w labie Docker.** Skrypt `scripts/configure-db.sh` (maszyna wirtualna) zawiera dodatkowo utwardzenie SSH, `auditd` i `unattended-upgrades`. Kontener `p02/db-srv` ma: nasłuch tylko na DB-NET, `pg_hba`, SCRAM-SHA-256, minimalne uprawnienia, firewall `nftables` i logowanie połączeń, ale **nie ma** SSH, `auditd` ani aktualizacji. Trzeba wybrać: pokazywać to na wersji VM, dopisać do obrazu, albo jasno opisać różnicę.
5. **Kolejność mówienia i podział demo** (patrz sekcja 5).

## 4. Co ma zrobić każda osoba

Role i właściciele wg `docs/Instrukcja_AI_projekt_P02_4_osoby.md`: Osoba 1 = APP i Docker (`Montjoje`), Osoba 2 = TLS, Nginx i WAF (`marzaw81122`), Osoba 3 = NETWORK i GNS3 (`Mikolaj12344321`), Osoba 4 = DB i hardening (`centelx`).

### Osoba 1: APP i Docker
- Zamknąć #1 (duplikat #6) i, po sprawdzeniu, #12.
- Dokończyć dowody do #20: log `docs/logs/app/app-tests-run.log` i zrzuty w `docs/screenshots/app/` (uruchomienie `tests/app-tests.sh`).
- Opisać w Blueprincie i raporcie sekcje o aplikacji i Dockerze (zabezpieczenia kontenera: użytkownik bez uprawnień, `cap_drop: ALL`, `read_only`, `no-new-privileges`) oraz rozdział „Laboratorium GNS3 na węzłach Docker” (źródło: `docs/lab-gns3-docker.md`).
- Dopisać do `HANDOVER.md` instrukcję uruchomienia labu (link do `lab/README.md`).
- Przygotować i przećwiczyć fragment demo: zapis do bazy, `GET /command` bez wykonania polecenia.

### Osoba 2: TLS, Nginx i WAF
- Dostarczyć do Blueprintu opisy: TLS 1.3, WAF (3 reguły), blokada SSH, logowanie ModSecurity, wraz z **uzasadnieniem** wyborów.
- Zebrać dowody do #22 po swojej stronie: wynik TLS 1.3, odrzucenie TLS 1.2, blokada SSH, SQLi, Path Traversal, log Command Injection, reguły nftables APP-SRV (w labie Docker: `nft list table inet app_sec` w konsoli APP-SRV).
- Sprawdzić `tests/tls-waf-tests.sh` na labie Docker (węzły mają inne wnętrze niż maszyny VM) i zamknąć #12 razem z Osobą 1.
- Przygotować i przećwiczyć fragment demo (sekcja 5).

### Osoba 3: NETWORK i GNS3
- Dodać do repozytorium `tests/network-tests.sh` (Issue #19) oraz do `network/README.md` wskazanie, że wersja Docker labu jest w `lab/`.
- Napisać **Network Security Blueprint** (#24): zawartość wg listy w Issue (cel, wymagania, założenia, diagram, komponenty, adresacja, macierz ruchu, TLS, WAF, firewall, logowanie, hardening DB, model zagrożeń, uzasadnienia, plan testów, ograniczenia). Diagram jest w `docs/blueprint/`, a sekcje o TLS/WAF/DB dostarczają Osoby 2 i 4.
- Zebrać dowody do #22: diagram działającej topologii GNS3, liczniki reguł routera (`nft list ruleset`), brak dostępu klienta do DB.
- Zdecydować (z zespołem), czy jego topologia Alpine/Qemu zostaje, czy zastępuje ją wersja Docker.
- Przygotować fragment demo: topologia, routing, segmentacja.

### Osoba 4: DB i hardening
- Napisać **raport z wdrożenia PoC** (#25) wg listy w Issue (cel, topologia, konfiguracja hostów, TLS, WAF, SSH, PostgreSQL, hardening, wyniki, logi, problemy i rozwiązania, wnioski). Wyniki testów są w `docs/poc-results.md`, opis labu w `docs/lab-gns3-docker.md`.
- Uzupełnić **`HANDOVER.md`** (#23) wg listy w Issue (stan, co działa i nie działa, uruchomienie GNS3, APP-SRV i DB-SRV, lokalizacje konfiguracji i logów, polecenia testowe, znane problemy, ostatni działający commit, sposób przekazywania sekretów bez zapisu w Git).
- Zebrać dowody do #22: reguły nftables DB-SRV, adres nasłuchu PostgreSQL, poprawny zapis do bazy, logi PostgreSQL.
- Rozstrzygnąć punkt 4 z sekcji 3 (zakres utwardzania DB-SRV w labie).
- Przygotować fragment demo: DB-SRV, hardening, logi.

### Wszyscy
- Zrobić próbę generalną demo (Issue #26): scenariusz w jednym pliku tekstowym z gotowymi komendami, zrzuty ekranu awaryjne, próba czasowa, kolejność mówienia.
- Każdy czyta cały `docs/lab-gns3-docker.md` i `docs/poc-results.md`: na obronie pytania mogą dotyczyć każdego elementu, nie tylko własnego.
- Zamknąć każde zadanie dopiero, gdy kryterium z Issue jest spełnione i w repo jest dowód.

## 5. Scenariusz demo na żywo (propozycja)

Środowisko: lab GNS3 uruchomiony wcześniej, konsole CLIENT, APP-SRV, DB-SRV i Router otwarte. Komendy przećwiczyć raz przed obroną, bo nie wszystkie były wykonywane w tym labie.

| Krok | Kto | Co pokazuje | Komendy (z konsoli CLIENT, o ile nie napisano inaczej) |
|---|---|---|---|
| 1 | Osoba 3 | topologia i segmentacja | okno GNS3, w konsoli Router `ip a` oraz `nft list ruleset` |
| 2 | Osoba 1 | aplikacja działa, zapis do bazy | `curl -k https://192.168.20.10/` oraz `curl -k -X POST https://192.168.20.10/message --data-urlencode "content=demo"` |
| 3 | Osoba 2 | TLS 1.3 działa, TLS 1.2 odrzucony | `openssl s_client -connect 192.168.20.10:443 -tls1_3 </dev/null \| grep -E "Protocol\|Cipher"` oraz to samo z `-tls1_2` |
| 4 | Osoba 2 | blokada SSH | `timeout 5 bash -c 'exec 3<>/dev/tcp/192.168.20.10/22'; echo $?` (wynik różny od 0), na APP-SRV `nft list table inet app_sec` |
| 5 | Osoba 2 | WAF: SQLi i Path Traversal zwracają 403 | `curl -k -i -X POST https://192.168.20.10/message --data-urlencode "content='OR 2>1--"` oraz `curl -k -i "https://192.168.20.10/file?name=../../../../../etc/passwd"` |
| 6 | Osoba 2 | Command Injection logowany, nie wykonany | `curl -k "https://192.168.20.10/command?cmd=ls%20-la"`, potem na APP-SRV `grep "Command Injection" /var/log/modsec_audit.log \| tail -3` |
| 7 | Osoba 4 | klient nie łączy się z bazą, APP-SRV łączy się | `timeout 5 bash -c 'exec 3<>/dev/tcp/192.168.30.10/5432'; echo $?` (różny od 0), na DB-SRV `ss -lntp \| grep 5432` i `runuser -u postgres -- psql -d webapp_db -c "SELECT count(*) FROM messages;"` |
| 8 | Osoba 3 | dowód filtrowania na routerze | `nft list ruleset \| grep -E "drop\|accept"` (liczniki rosną) |
| 9 | Wszyscy | automatyczny komplet testów | `bash /opt/p02/tests/poc-tests.sh client` (PASS=9) |

## 6. Czego każdy musi się nauczyć i co umieć powiedzieć na obronie

Na obronie prowadzący zwykle pyta „dlaczego tak” i „co się stanie, jeśli”. Dla każdej osoby: pojęcia, co pokazać i przykładowe pytania z krótkim kierunkiem odpowiedzi.

### Osoba 1: APP i Docker
**Pojęcia do opanowania:** endpointy aplikacji (`GET /`, `POST /message`, `GET /file`, `GET /command`); zapytania parametryzowane (wartość nie jest sklejana z SQL, więc SQLi nie działa na poziomie aplikacji); konfiguracja z zmiennych środowiskowych (hasło do bazy poza Git); Dockerfile i utwardzenie kontenera (użytkownik bez uprawnień, `cap_drop: ALL`, `read_only`, `no-new-privileges`); gunicorn za reverse proxy na `127.0.0.1:5000`.
**Pokaż:** zapis rekordu przez `POST /message` i jego obecność w bazie; `GET /command` zwraca `executed:false`; `app/compose.lab.yaml`.
**Pytania:**
- Skoro zapytania są parametryzowane, po co WAF? (Obrona warstwowa: WAF blokuje atak, zanim dotrze do aplikacji, a parametryzacja chroni, gdyby WAF został obejściem.)
- Dlaczego `/command` nie wykonuje poleceń? (To celowo „podatny” endpoint tylko do testów WAF; wymaganie mówi o logowaniu, z gwarancją niewykonania polecenia.)
- Gdzie jest hasło do bazy? (Zmienne `DB_*`, w repo tylko `CHANGE_ME` w `.env.example`; w labie Docker domyślne hasło laboratoryjne.)
- Dlaczego kontener nie działa jako root? (Ograniczenie skutków przejęcia procesu.)

### Osoba 2: TLS, Nginx i WAF
**Pojęcia do opanowania:** handshake TLS i czym TLS 1.3 różni się od 1.2 (mniej zestawów szyfrów, szybszy handshake, obowiązkowy forward secrecy); certyfikat X.509 i SAN, samopodpisany certyfikat (dlatego `curl -k`); ModSecurity v3 jako moduł Nginx, OWASP CRS (punktowanie anomalii), reguły własne `100001–100003` (fazy, `chain`, `deny` kontra `pass`, tryb `DetectionOnly` dla Command Injection); log audytowy `/var/log/modsec_audit.log`; host-based WAF (single-server) kontra WAF sieciowy; dwie warstwy blokady SSH (brak usługi + reguła `nftables`, a na ścieżce klienta także router).
**Pokaż:** komendy z kroków 3–6 scenariusza demo.
**Pytania:**
- Dlaczego tylko TLS 1.3? (Wymaganie tematu; eliminuje przestarzałe szyfry i protokoły.)
- Dlaczego Command Injection tylko logujemy? (Tak mówi wymaganie; aplikacja i tak nie wykonuje poleceń.)
- Skąd wiadomo, że blokada pochodzi z WAF, a nie z aplikacji? (Odpowiedź 403 i wpis w logu audytowym z identyfikatorem reguły.)
- Co to jest anomaly scoring w CRS? (Reguły dodają punkty, a żądanie jest blokowane po przekroczeniu progu.)
- Jak jeszcze można zablokować SSH? (Firewall, wyłączenie usługi, `AllowUsers`, brak portu na zewnątrz.)

### Osoba 3: NETWORK i GNS3
**Pojęcia do opanowania:** podsieci i maski (`/24`), rola routera, segmentacja i strefa DMZ, `nftables` (tabela, łańcuch `forward`, polityka domyślna `drop`, stan połączeń `ct state established,related`), macierz ruchu jako zasada najmniejszych uprawnień, jak działa nasza topologia w GNS3 (węzły Docker w GNS3 VM, adresy ustawiane przez skrypt startowy).
**Pokaż:** topologia i adresacja, `nft list ruleset` z licznikami, ping klient → router i APP-SRV, brak łączności klient → DB.
**Pytania:**
- Po co trzy segmenty? (Atak na aplikację nie daje bezpośredniej drogi do bazy; DB jest w osobnej sieci.)
- Po co filtrować na routerze, skoro hosty mają własne firewalle? (Obrona warstwowa; błąd w jednym miejscu nie otwiera całej sieci.)
- Co oznacza polityka `drop` i dlaczego odpowiedzi nadal wracają? (Reguła stanu połączenia przepuszcza ruch powiązany.)
- Co by się stało, gdyby klient próbował połączyć się z bazą? (Router odrzuca pakiet, licznik reguły rośnie.)
- Dlaczego użyliśmy kontenerów, a nie maszyn wirtualnych? (Brak KVM na komputerze z włączoną wirtualizacją Windows; kontenery uruchamiają się szybko i dają się odtworzyć skryptem.)

### Osoba 4: DB i hardening
**Pojęcia do opanowania:** PostgreSQL: `listen_addresses`, `pg_hba.conf` (kto, skąd, do której bazy i jakim uwierzytelnieniem), SCRAM-SHA-256 (hasła nie są przechowywane jawnie ani w słabym skrócie), minimalne uprawnienia konta aplikacji (`SELECT`, `INSERT` na `messages`), logowanie połączeń; firewall hostowy `nftables` z polityką `drop` i dostępem do 5432 tylko z APP-SRV; utwardzenie SSH, `auditd` i automatyczne aktualizacje (w wersji VM).
**Pokaż:** `ss -lntp | grep 5432`, reguły `nftables`, plik `pg_hba.conf`, uprawnienia roli (`\du`, `\dp messages`), log połączeń.
**Pytania:**
- Dlaczego baza nie nasłuchuje na `0.0.0.0`? (Mniejsza powierzchnia ataku, tylko adres DB-NET i localhost.)
- Co robi `pg_hba.conf`? (Domyślnie odrzuca wszystko, co nie jest wymienione; dopuszczony jest tylko `webapp_user` z `192.168.20.10`.)
- Dlaczego konto aplikacji nie ma `DROP`/`UPDATE`? (Najmniejsze uprawnienia: przejęta aplikacja nie zniszczy danych.)
- Dlaczego utwardzamy tylko DB-SRV? (Takie jest wymaganie tematu; aplikację chronią TLS i WAF.)
- Czy ruch APP → DB jest szyfrowany? (Obecnie nie; jest ograniczony do DB-NET i regułami routera. Trzeba mieć gotowe uzasadnienie albo wdrożyć SSL, patrz sekcja 3, punkt 3.)

### Pytania do wszystkich (całość projektu)
- Jakie zagrożenia rozwiązuje każda warstwa (TLS, WAF, router, firewall DB, hardening DB)? Co się stanie, gdy jedna z nich zawiedzie?
- Dlaczego APP-SRV i DB-SRV są na dwóch hostach? (Wymaganie tematu i izolacja warstwy danych.)
- Co udowodniliśmy i czym (11 testów, `docs/poc-results.md`, liczniki reguł routera, logi)? Co zostało nieudowodnione lub uproszczone (sekcja 5 `docs/lab-gns3-docker.md`)?
- Co by się zmieniło w produkcji (certyfikat z zaufanego CA, hasła z menedżera sekretów, szyfrowanie APP → DB, centralne logi)?
