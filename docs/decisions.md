# Ustalenia projektowe

Ten plik zawiera ustalenia, których nie należy zmieniać bez uzgodnienia z drugą osobą.

## Podział odpowiedzialności

### Osoba A

- aplikacja WWW,
- Docker,
- Nginx,
- TLS 1.3,
- ModSecurity,
- reguły WAF,
- blokada SSH na APP-SRV.

### Osoba B

- projekt GNS3,
- router i segmentacja,
- DB-SRV,
- PostgreSQL,
- firewall serwera bazy,
- hardening DB-SRV.

## Adresacja

| Element | Adres |
|---|---|
| CLIENT-NET | 192.168.10.0/24 |
| Brama klienta | 192.168.10.1 |
| DMZ | 192.168.20.0/24 |
| APP-SRV | 192.168.20.10 |
| Brama APP-SRV | 192.168.20.1 |
| DB-NET | 192.168.30.0/24 |
| DB-SRV | 192.168.30.10 |
| Brama DB-SRV | 192.168.30.1 |

## Usługi

| Usługa | Port |
|---|---:|
| HTTPS | TCP/443 |
| PostgreSQL | TCP/5432 |
| SSH na APP-SRV | TCP/22, zablokowany |

## Baza danych

- nazwa bazy: `webapp_db`
- użytkownik aplikacyjny: `webapp_user`
- adres bazy: `192.168.30.10`
- port bazy: `5432`

## Zasada zmian

Każda zmiana adresacji, portów, nazw usług lub odpowiedzialności musi zostać zapisana w tym pliku.
