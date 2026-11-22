# Instrukcja odtworzenia maszyny `APP-SRV` (klon KSO Debian 13)

Dokument opisuje szybkie i powtarzalne odtworzenie skonfigurowanej maszyny `APP-SRV` na bazie czystego klonu Debian 13 z KSO, bez konieczności przesyłania wielogigabajtowego obrazu `.ova`.

Automatyzację zapewnia skrypt `waf/setup-app-srv.sh`, który wdraża pliki konfiguracyjne z tego repozytorium:
- Nginx jako reverse proxy na `TCP/443` z wymuszonym wyłącznie `TLSv1.3` (bez portu `80`),
- certyfikat laboratoryjny X.509 (RSA 4096 z `SAN: DNS:secure-app.lab, IP:192.168.20.10`),
- WAF ModSecurity v3 + OWASP CRS + reguły dedykowane (SQLi, Path Traversal, logowanie Command Injection),
- trwałą zaporę `nftables` blokującą i logującą `TCP/22` oraz wyłączenie usługi SSH (opcjonalnie na ostatnim etapie przez flagę `--lock-ssh`).

Domyślny użytkownik administracyjny na bazowym klonie: `user1` (oraz `root`).

---

## 1. Przygotowanie maszyny wirtualnej (VirtualBox)

1. Utwórz pełny klon bazowego obrazu Debian 13 (KSO) i nazwij maszynę `APP-SRV`.
2. Podczas klonowania wybierz opcję wygenerowania nowych adresów MAC dla wszystkich kart sieciowych (*Generate new MAC addresses for all network adapters*).
3. Skonfiguruj dwie karty sieciowe w ustawieniach maszyny:
   - **Adapter 1 (`enp0s3`):** `NAT` — zapewnia dostęp do internetu na czas instalacji pakietów (`apt`), pobrania repozytorium (`git`) i zbudowania obrazów Dockera.
   - **Adapter 2 (`enp0s8`):** sieć projektu (np. podpinana do topologii GNS3 lub `Internal Network` / `Host-Only` dla podsieci DMZ `192.168.20.0/24`).

---

## 2. Konfiguracja sieci na `APP-SRV`

Uruchom maszynę i zaloguj się jako `root` (lub jako `user1` i użyj `sudo`). Sprawdź nazwy interfejsów poleceniem `ip a`, a następnie skonfiguruj statyczny adres IP `192.168.20.10/24` na interfejsie projektu (`enp0s8`).

### Wariant A — docelowa sieć w GNS3 (gdy `enp0s3` NAT zostanie wyłączony po instalacji)

```bash
nmcli con add type ethernet ifname enp0s8 con-name dmz-app \
  ipv4.method manual \
  ipv4.addresses 192.168.20.10/24 \
  ipv4.gateway 192.168.20.1
nmcli con up dmz-app
```

*(Jeśli brama podsieci DMZ na routerze w GNS3 ma inny adres niż `192.168.20.1`, podmień parametr `ipv4.gateway`.)*

### Wariant B — gdy oba interfejsy (`NAT` + sieć projektu) działają jednocześnie

Jeśli `enp0s3` (NAT) jest aktywne podczas integracji, nie ustawiaj drugiej bramy domyślnej na `enp0s8`, aby uniknąć konfliktu routingu. Zamiast tego przypisz sam adres IP oraz trasy statyczne do podsieci klienta (`192.168.10.0/24`) i bazy danych (`192.168.30.0/24`):

```bash
nmcli con add type ethernet ifname enp0s8 con-name dmz-app \
  ipv4.method manual \
  ipv4.addresses 192.168.20.10/24 \
  +ipv4.routes "192.168.10.0/24 192.168.20.1" \
  +ipv4.routes "192.168.30.0/24 192.168.20.1"
nmcli con up dmz-app
```

Po zbudowaniu kontenerów Dockera kartę `enp0s3` (NAT) można całkowicie wyłączyć lub odpiąć w GNS3, przechodząc na domyślną bramę routera projektu.

---

## 3. Etap 1 — wdrożenie Nginx, TLS 1.3 i WAF (z aktywnym SSH)

Sklonuj repozytorium i uruchom skrypt w trybie podstawowym (bez blokowania SSH, aby wygodnie dokończyć konfigurację aplikacji i połączenia z `DB-SRV`):

```bash
git clone https://github.com/Montjoje/network-security-p02.git /opt/network-security-p02
cd /opt/network-security-p02
chmod +x waf/setup-app-srv.sh
sudo ./waf/setup-app-srv.sh
```

Skrypt automatycznie:
- ustawi nazwę hosta `app-srv` i wpis w `/etc/hosts`,
- zainstaluje `nginx`, `libnginx-mod-http-modsecurity`, `modsecurity-crs`, `nftables` (oraz `docker.io`, jeśli nie był obecny),
- wygeneruje certyfikat X.509 z SAN i zabezpieczy klucz prywatny (`chmod 600`),
- wdroży pliki konfiguracyjne z `waf/` (usuwając ewentualne końce linii `CRLF`),
- utworzy `/var/log/modsec_audit.log` z uprawnieniami dla `www-data`,
- skopiuje skrypt testowy do `/root/tls-waf-tests.sh` i przeładuje `nginx`.

---

## 4. Uruchomienie aplikacji Flask i spięcie z `DB-SRV`

1. Zbuduj i uruchom kontener aplikacji z katalogu `/opt/network-security-p02/app/`.
2. Upewnij się, że aplikacja:
   - nasłuchuje wyłącznie lokalnie na `127.0.0.1:5000` (mapowanie portów `127.0.0.1:5000:5000` w Docker Compose),
   - łączy się z docelowym serwerem bazy danych `DB-SRV` (`192.168.30.10:5432`) zgodnie z konfiguracją środowiska.
3. Sprawdź wstępnie działanie stosu HTTPS + WAF:

```bash
sudo /root/tls-waf-tests.sh 192.168.20.10
```

---

## 5. Etap 2 — wyłączenie SSH i aktywacja `nftables`

**Uwaga:** ten krok wykonaj z **lokalnej konsoli maszyny wirtualnej** (VirtualBox / GNS3), ponieważ aktywna sesja SSH zostanie rozłączona.

```bash
sudo /opt/network-security-p02/waf/setup-app-srv.sh --lock-ssh
```

Skrypt:
- zatrzyma i wyłączy z autostartu usługi `ssh` oraz `ssh.socket`,
- aktywuje dedykowaną tabelę `inet app_sec` w `/etc/nftables.conf`, która odrzuca i loguje ruch przychodzący na `TCP/22` z prefiksem `NFT-SSH-BLOCK: `, nie naruszając reguł sieciowych Dockera.

---

## 6. Restart i weryfikacja końcowa

Wykonaj pełny restart maszyny, aby potwierdzić trwałość konfiguracji:

```bash
sudo reboot
```

Po ponownym uruchomieniu sprawdź na `APP-SRV` (z lokalnej konsoli):

```bash
sudo /root/tls-waf-tests.sh 192.168.20.10
sudo ss -lntp | grep -E ":(22|80|443|5000)\b"
sudo systemctl is-active ssh || echo "SSH nieaktywne"
sudo nft list table inet app_sec
```

Z maszyny klienta (Linux w GNS3) przetestuj zablokowanie portu SSH:

```bash
nc -zv -w 3 192.168.20.10 22
```

Następnie na `APP-SRV` potwierdź zapisanie zablokowanej próby w logu jądra:

```bash
sudo journalctl -k | grep "NFT-SSH-BLOCK" | tail -n 5
```

### Kryteria zaliczenia
- `/root/tls-waf-tests.sh 192.168.20.10` zwraca `PASS=11, FAIL=0, SKIP=0` (kod wyjścia `0`).
- `ss -lntp` pokazuje nasłuch wyłącznie na `0.0.0.0:443` (`nginx`) oraz `127.0.0.1:5000` (`docker-proxy`) — brak portów `22` i `80`.
- Połączenie `nc` na port `22` kończy się niepowodzeniem, a zdarzenie jest widoczne w `journalctl -k` z prefiksem `NFT-SSH-BLOCK:`.

---

## 7. Zarządzanie maszyną po zamknięciu SSH

Po wykonaniu kroku `--lock-ssh` zdalny dostęp SSH jest celowo zablokowany. Bieżąca administracja `APP-SRV` (podgląd `/var/log/modsec_audit.log`, `journalctl -k`, zarządzanie kontenerami i usługami) odbywa się wyłącznie przez lokalną konsolę VM w GNS3 / VirtualBox.