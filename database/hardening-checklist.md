# Checklist Hardeningu Serwera Bazy Danych (DB-SRV)

Dokument podsumowuje wdrożone zabezpieczenia i procedury hardeningu na maszynie **DB-SRV** (Debian 13) w ramach projektu P02.

---

## 1. Aktualizacje systemu i pakiety bezpieczeństwa

- **Polecenie:**
  ```bash
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y unattended-upgrades apt-listchanges
  sudo systemctl enable --now unattended-upgrades
  ```
- **Uzasadnienie:**
  Zapewnienie najnowszych łatek bezpieczeństwa dla jądra i bibliotek systemowych. Usługa `unattended-upgrades` automatycznie instaluje krytyczne poprawki CVE bez konieczności manualnej interwencji.
- **Dowód testu:**
  ```bash
  systemctl is-active unattended-upgrades
  # Wynik: active
  ```

---

## 2. Minimalizacja usług i powierzchni ataku

- **Polecenie:**
  ```bash
  sudo ss -tulpn
  ```
- **Uzasadnienie:**
  Zasada minimalizacji powierzchni ataku. Na serwerze bazy danych nie powinny działać żadne zbędne demony (np. serwery WWW, serwery pocztowe, usługi RPC).
- **Dowód testu:**
  Weryfikacja portów wykazała wyłącznie:
  - TCP/22 (`sshd`) – ograniczony dostęp administracyjny
  - TCP/5432 (`postgres`) – nasłuch na `127.0.0.1` oraz `192.168.30.10`

---

## 3. Hardening usługi SSH

- **Plik konfiguracji:** `/etc/ssh/sshd_config.d/p02-hardening.conf`
  ```text
  PermitRootLogin no
  AllowUsers vboxuser
  MaxAuthTries 3
  LoginGraceTime 30
  PermitEmptyPasswords no
  ClientAliveInterval 300
  ClientAliveCountMax 2
  ```
- **Uzasadnienie:**
  - Blokada bezpośredniego logowania na konto `root` uniemożliwia przejęcie najwyższych uprawnień przez sieć.
  - Ograniczenie użytkowników (`AllowUsers`) zapobiega próbom logowania na konta techniczne.
  - Limit prób autoryzacji (`MaxAuthTries 3`) i krótki czas oczekiwania (`LoginGraceTime 30`) chronią przed atakami typu brute-force.
- **Dowód testu:**
  ```bash
  sudo sshd -T | grep -E "permitrootlogin|allowusers|maxauthtries"
  # Wynik:
  # maxauthtries 3
  # permitrootlogin no
  # allowusers vboxuser
  ```

---

## 4. Ograniczenie sieciowe i autoryzacji PostgreSQL

- **Pliki konfiguracji:**
  - `database/postgresql.conf.fragment`
  - `database/pg_hba.conf.fragment`
- **Zastosowane reguły:**
  - `listen_addresses = '127.0.0.1, 192.168.30.10'` (brak `0.0.0.0`)
  - `password_encryption = scram-sha-256`
  - W `pg_hba.conf` zezwolono na dostęp do `webapp_db` wyłącznie dla `webapp_user` z adresu `192.168.20.10/32` (APP-SRV).
- **Uzasadnienie:**
  Baza danych nie jest widoczna w publicznych sieciach ani dla klientów (`192.168.10.0/24`). Hasła chronione są nowoczesnym algorytmem SCRAM-SHA-256 zamiast podatnego MD5.
- **Dowód testu:**
  Test z adresem klienta `192.168.10.10` zwrócił:
  `FATAL: no pg_hba.conf entry for host "192.168.10.10", user "webapp_user", database "webapp_db"`

---

## 5. Dedykowany użytkownik aplikacyjny i zasada Least Privilege

- **Plik SQL:** `database/init.sql`
- **Uzasadnienie:**
  Aplikacja nie może łączyć się jako superuser (`postgres`). Użytkownik `webapp_user` posiada wyłącznie prawa `SELECT` i `INSERT` do tabeli `messages` oraz brak uprawnień do modyfikacji schematu bazy danych.
- **Dowód testu:**
  ```bash
  sudo -u postgres psql -d webapp_db -c "\du webapp_user"
  # Wynik: Attributes: No inheritance (brak praw Superuser, Create role, Create DB)
  
  psql -U webapp_user -c "CREATE TABLE test (id int);"
  # Wynik: ERROR: permission denied for schema public
  ```

---

## 6. Firewall hostowy nftables

- **Plik konfiguracji:** `database/nftables.conf`
- **Uzasadnienie:**
  Druga linia obrony (Defense in Depth). Domyślna polityka `DROP` odrzuca każdy niezdefiniowany ruch. Dostęp do portu 5432 jest dozwolony wyłącznie z IP `192.168.20.10`.
- **Dowód testu:**
  Próba połączenia z IP `192.168.10.10` na port 5432 skutkuje zrzuceniem pakietu SYN i wpisem w dmesg:
  `[NFT-DROP] ... SRC=192.168.10.10 DST=192.168.30.10 ... DPT=5432`

---

## 7. Audyt jądra (auditd)

- **Plik reguł:** `/etc/audit/rules.d/p02-db-srv.rules`
  - Monitorowanie katalogu `/etc/postgresql/` (`-k db_config_change`)
  - Monitorowanie pliku `/etc/nftables.conf` (`-k firewall_change`)
  - Monitorowanie konfiguracji `/etc/ssh/` (`-k ssh_config_change`)
  - Monitorowanie tożsamości `/etc/passwd` i `/etc/shadow` (`-k identity_change`)
- **Uzasadnienie:**
  Zapewnienie rozliczalności i natychmiastowego wykrywania nieautoryzowanych modyfikacji w konfiguracji bazy danych, reguł zapory sieciowej oraz kont systemowych.
- **Dowód testu:**
  ```bash
  sudo auditctl -l
  # Wynik: załadowane reguły dla -w /etc/postgresql, /etc/nftables.conf, /etc/ssh, /etc/passwd, /etc/shadow
  
  sudo ausearch -k db_config_change
  # Wynik: zarejestrowanie zdarzeń touch/rm w katalogu /etc/postgresql/17/main/conf.d/
  ```

---

## 8. Logowanie audytowe PostgreSQL

- **Ustawienia:** `log_connections = on`, `log_disconnections = on`, `log_line_prefix = '%m [%p] %q%u@%d '`
- **Uzasadnienie:**
  Rejestrowanie każdego udanego i odrzuconego połączenia z bazą danych wraz ze znacznikiem czasu, identyfikatorem procesu, użytkownikiem i adresem IP klienta.
- **Dowód testu:**
  Plik `/var/log/postgresql/postgresql-17-main.log` rejestruje zdarzenia:
  `LOG: connection authorized: user=postgres ...`
  `FATAL: no pg_hba.conf entry for host "192.168.10.10" ...`
