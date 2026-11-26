# HANDOVER – stan projektu P02 (Bezpieczna aplikacja WWW)

Dokument opisuje stan repozytorium i laboratorium na 2026-11-26. Aktualizuj go przy każdej większej zmianie. Dla członka zespołu, który przejmuje część pracy, to jest punkt startowy.

## 1. Decyzja: system na hostach – Debian 13

Decyzja z 2026-11-26: `APP-SRV` i `DB-SRV` działają na **Debianie 13**. Zgodnie z wymaganiami projektu i z dotychczasowym PoC.

Obecne obrazy w GNS3 są na Alpine Linux 3.24. Trzeba zbudować nowe obrazy Debiana 13 dla obu hostów. Router może zostać na Alpine, bo jego konfiguracja jest niezależna od systemu hostów. Skrypty `waf/setup-app-srv.sh` i `scripts/configure-db.sh` pozostają bez zmian (używają `apt` i układu Debiana).

## 2. Stan elementów

| Obszar | Stan | Gdzie |
|---|---|---|
| Adresacja, macierz ruchu | Gotowe, zgodne z GNS3 | `network/addressing.md`, `network/traffic-matrix.md` |
| Router (GNS3) | Gotowe: interfejsy, `ip_forward`, nftables. Składnia sprawdzona. | `network/gns3/router/` |
| Hosty w GNS3 (adresy, bramy) | Gotowe: IP i bramy zgodne z tabelą | `network/gns3/*/etc/network/interfaces` |
| Hosty w GNS3 (usługi) | **Nie wykonane.** Obecne obrazy są na Alpine, a decyzja to Debian 13: trzeba zbudować nowe obrazy. | – |
| Aplikacja Flask, Docker Compose | Gotowe (gałąź `app`, scalona) | `app/` |
| TLS 1.3, Nginx, ModSecurity, OWASP CRS | Gotowe i przetestowane w kopii VirtualBox | `waf/`, `tests/tls-waf-tests.sh` |
| Blokada SSH na APP-SRV | Gotowe w skrypcie (`--lock-ssh`) i przetestowane w kopii | `waf/setup-app-srv.sh`, `waf/nftables.conf` |
| Hardening DB-SRV | Gotowe w skrypcie i przetestowane w kopii | `scripts/configure-db.sh`, `database/` |
| Testy sieci | Dodane do repozytorium (`tests/network-tests.sh`) | `tests/` |
| Test PoC end-to-end | Wykonany w kopii VirtualBox, **nie w GNS3** | `docs/poc-results.md` |
| Diagram, raport z projektu | Diagram `docs/blueprint/`. Raport do napisania. | `docs/blueprint/`, `docs/requirements.md` |

## 3. Co trzeba zrobić, w kolejności

1. ~~Podjąć decyzję z punktu 1.~~ (zrobione: Debian 13)
2. Zbudować obrazy Debian 13 dla `app-server` i `db-server` w GNS3 (adresy z `network/gns3/README.md`). Dopiero potem uruchomić `waf/setup-app-srv.sh` i `scripts/configure-db.sh`.
3. Wyłączyć i odłączyć `eth1` (NAT) na `app-server` i `db-server` po instalacji pakietów. Dzięki temu DB-SRV nie ma wyjścia do internetu.
4. Wyłączyć `sshd` na `app-server` (`rc-update del sshd` lub `systemctl disable --now ssh`). Obecnie jest uruchamiany przy starcie.
5. Uruchomić testy: `sh /root/network-tests.sh client|app|db`, potem `tests/tls-waf-tests.sh`, `tests/database-tests.sh`, `tests/app-tests.sh` i `tests/poc-tests.sh`.
6. Zebrać logi i zrzuty do `docs/logs/` i `docs/screenshots/`, zaktualizować `docs/poc-results.md`.
7. Napisać raport z wdrożenia (4 pkt) i przygotować prezentację (5 pkt).

## 4. Znane problemy i uwagi

- `docs/decisions.md` odwołuje się do `docs/logs/app/integration-poc.log`. Ten plik nie istnieje w repozytorium.
- Plan zespołu przewiduje `CHANGELOG.md`. Nie ma go jeszcze.
- W `database/nftables.conf` SSH na DB-SRV (`tcp dport 22`) jest otwarte bez ograniczenia źródła. Router przepuszcza tylko TCP/5432 z APP-SRV, więc w obecnym układzie port jest nieosiągalny spoza hosta. Zawęzić do adresu administracyjnego, gdy będzie znany.
- W `/etc/hosts` klienta w obrazie wpis `127.0.0.1` zawiera nazwę `app-server`. Nie wpływa na testy, ale warto poprawić.
- Obrazy `hda_disk.qcow2` z projektu GNS3 mają wbudowany stan systemów. Nie wrzucać ich do repozytorium (zasady z `docs/Instrukcja_AI_projekt_P02_4_osoby.md`, sekcja 13).

## 5. Jak zacząć pracę (dla nowej osoby)

```bash
git clone https://github.com/Montjoje/network-security-p02.git
cd network-security-p02
git branch --show-current
git status
```

Przed pracą przeczytaj: `docs/requirements.md`, `docs/decisions.md`, `network/gns3/README.md`. Podział odpowiedzialności: `docs/decisions.md`, sekcja „Podział odpowiedzialności”.
