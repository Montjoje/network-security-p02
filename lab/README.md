# Lab P02 w GNS3 na wezlach Docker

Wersja labu, ktora dziala **bez KVM i bez VirtualBox**: wszystkie 4 wezly (router, klient,
APP-SRV, DB-SRV) to kontenery Docker uruchamiane przez GNS3 w maszynie GNS3 VM.
Adresacja, reguly routera, konfiguracja WAF/TLS i utwardzanie DB-SRV sa te same
co w katalogach `network/`, `waf/` i `database/`.

| Wezel | Obraz | Adres | Co dziala |
|---|---|---|---|
| Router | `p02/router` | .10.1 / .20.1 / .30.1 (eth0/eth1/eth2) | nftables, forward = drop (`lab/router/nftables.conf`) |
| CLIENT | `p02/client` | 192.168.10.10 | curl, openssl, testy `poc-tests.sh` |
| APP-SRV | `p02/app-srv` | 192.168.20.10 | Nginx TLS 1.3 + ModSecurity + OWASP CRS, Flask (gunicorn), nftables tcp/22 DROP |
| DB-SRV | `p02/db-srv` | 192.168.30.10 | PostgreSQL (utwardzony: pg_hba, nasluch tylko na DB-NET, nftables) |

Uproszczenia wzgledem maszyn wirtualnych (do opisania w raporcie): aplikacja Flask dziala
w tym samym kontenerze co Nginx (bez Dockera w Dockerze); na APP-SRV nie dziala zaden serwer SSH,
a port 22 jest dodatkowo odrzucany przez nftables; certyfikat TLS generuje sie przy pierwszym starcie.
Haslo konta bazy (`P02-lab-Passw0rd`) jest tylko laboratoryjne i mozna je zmienic zmienna `DB_PASSWORD`.

## Wymagania
- GNS3 2.2.x + GNS3 VM (VirtualBox) z **dostepem do internetu** (w ustawieniach VM karta 2: NAT lub mostkowana).
- Python 3 na komputerze z GNS3 (skrypt tworzacy topologie).

## Krok 1: zbuduj obrazy w GNS3 VM
W konsoli GNS3 VM (okno VirtualBoxa -> **Shell**):
```bash
git clone -b lab-docker https://github.com/Montjoje/network-security-p02.git
cd network-security-p02
bash lab/build.sh
```
Na koncu pojawi sie lista czterech obrazow `p02/...`.

## Krok 2: utworz projekt GNS3
W PowerShell na Windowsie (w katalogu repozytorium; port to port serwera z GNS3 -> Edit -> Preferences -> Server):
```powershell
python lab\gns3\create-project.py --server http://127.0.0.1:3080 --start
```
Skrypt tworzy projekt `p02-lab-docker` z 4 wezlami i 3 lacami. Potem w GNS3: **File -> Open project**.

## Krok 3: testy (konsole wezlow: prawy przycisk -> Console)
Poczekaj okolo 1 minuty po starcie (generowanie certyfikatu, start PostgreSQL).

CLIENT:
```bash
bash /opt/p02/tests/poc-tests.sh client 2>&1 | tee /root/poc-client-gns3.log
```
APP-SRV (zamien MARKER na wartosc `MARKER=...` wypisana przez klienta):
```bash
bash /opt/p02/tests/poc-tests.sh app 192.168.20.10 192.168.30.10 MARKER 2>&1 | tee /root/poc-app-gns3.log
```
Router (dowod filtrowania, liczniki pakietow):
```bash
nft list ruleset | grep -E "drop|accept"
```
Test 11 (po restarcie): w GNS3 zatrzymaj i uruchom ponownie wezly (Router pierwszy), poczekaj 1 minute
i powtorz testy.

## Rozwiazywanie problemow
- `docker` w GNS3 VM zwraca blad uprawnien: `build.sh` uzywa `sudo docker` automatycznie.
- Wezel nie ma adresu IP: w konsoli `ip a`; logi startu: `cat /proc/1/fd/1` nie dziala - wpisz `ip a` i uruchom wezel ponownie.
- Zmiana obrazu: po `git pull` i `bash lab/build.sh` zatrzymaj wezly, usun je (Delete) i utworz projekt od nowa skryptem.
