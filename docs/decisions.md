# Ustalenia projektowe

Ten plik zawiera ustalenia, których nie należy zmieniać bez uzgodnienia z zespołem (4 osoby).

## Podział odpowiedzialności

### Osoba 1: APP i Docker (gałąź `app`)

- aplikacja Flask i jej endpointy (`GET /`, `POST /message`, `GET /file`, `GET /command`),
- połączenie z PostgreSQL i parametryzowane zapytania SQL,
- Dockerfile, Docker Compose, zmienne środowiskowe,
- testy funkcjonalne aplikacji (`tests/app-tests.sh`).

### Osoba 2: TLS, Nginx i WAF (gałąź `waf-tls`)

- Nginx, certyfikat laboratoryjny, TLS 1.3 (odrzucenie TLS 1.2),
- ModSecurity, OWASP CRS, reguły SQLi, Path Traversal i Command Injection,
- blokada SSH na APP-SRV,
- testy TLS i WAF (`tests/tls-waf-tests.sh`).

### Osoba 3: NETWORK i GNS3 (gałąź `network`)

- topologia GNS3, router, trzy segmenty sieci,
- adresacja, routing, filtrowanie ruchu, macierz ruchu,
- testy segmentacji (`tests/network-tests.sh`),
- widoki topologii, eksport projektu GNS3.

### Osoba 4: DB i hardening (gałąź `database`)

- PostgreSQL, baza `webapp_db`, użytkownik `webapp_user`, tabela `messages`,
- `postgresql.conf`, `pg_hba.conf`, SCRAM-SHA-256,
- nftables na DB-SRV, hardening DB-SRV, logi PostgreSQL, auditd,
- testy bazy danych (`tests/database-tests.sh`), instrukcja przejęcia projektu.

### Granice odpowiedzialności

- Osoba 1 nie konfiguruje docelowego DB-SRV ani WAF.
- Osoba 2 nie zmienia kodu aplikacji bez uzgodnienia z Osobą 1.
- Osoba 3 odpowiada za przepływy sieciowe, ale hostowy firewall DB-SRV przygotowuje Osoba 4.
- Osoba 4 nie zmienia aplikacji Osoby 1 bez uzgodnienia.

## Adresacja

| Element | Adres |
|---|---|
| CLIENT-NET | 192.168.10.0/24 |
| Brama CLIENT-NET | 192.168.10.1 |
| Klient testowy | 192.168.10.10 |
| DMZ | 192.168.20.0/24 |
| Brama DMZ | 192.168.20.1 |
| APP-SRV | 192.168.20.10 |
| DB-NET | 192.168.30.0/24 |
| Brama DB-NET | 192.168.30.1 |
| DB-SRV | 192.168.30.10 |

## Usługi

| Usługa | Port |
|---|---:|
| HTTPS | TCP/443 |
| PostgreSQL | TCP/5432 |
| SSH na APP-SRV | TCP/22, zablokowany |

## Macierz ruchu

| Źródło | Cel | Port | Decyzja |
|---|---|---:|---|
| CLIENT | APP-SRV | TCP/443 | zezwól |
| CLIENT | APP-SRV | TCP/80 | zablokuj |
| CLIENT | APP-SRV | TCP/22 | zablokuj |
| CLIENT | DB-SRV | wszystkie | zablokuj |
| APP-SRV | DB-SRV | TCP/5432 | zezwól |
| APP-SRV | DB-SRV | pozostałe | zablokuj |

## Baza danych

- nazwa bazy: `webapp_db`
- użytkownik aplikacyjny: `webapp_user`
- adres bazy: `192.168.30.10`
- port bazy: `5432`
- hasło: tylko w niewersjonowanym pliku `.env`, w repozytorium wyłącznie `CHANGE_ME` w `.env.example`

## Zasada zmian

Każda zmiana adresacji, portów, nazw usług lub odpowiedzialności musi zostać zapisana w tym pliku.

## Dziennik zmian

- Zmiana podziału zespołu z 2 osób (A/B) na 4 osoby (Osoba 1–4); dodano macierz ruchu, granice odpowiedzialności oraz adresy klienta testowego i bram segmentów.
