# Adresacja Sieciowa

W projekcie wykorzystano trzy oddzielne segmenty sieciowe połączone centralnym routerem.

## Podsumowanie podsieci

| Nazwa sieci | Adres sieci | Maska | Brama domyślna (Router) |
| :--- | :--- | :--- | :--- |
| **CLIENT-NET** | `192.168.10.0` | `/24` (`255.255.255.0`) | `192.168.10.1` |
| **DMZ (APP)** | `192.168.20.0` | `/24` (`255.255.255.0`) | `192.168.20.1` |
| **DB-NET** | `192.168.30.0` | `/24` (`255.255.255.0`) | `192.168.30.1` |

## Adresacja hostów

| Komponent | Rola | Adres IP | Brama domyślna |
| :--- | :--- | :--- | :--- |
| **Klient testowy** | Maszyna z przeglądarką w sieci użytkowników | `192.168.10.10` | `192.168.10.1` |
| **APP-SRV** | Serwer aplikacyjny (Nginx, WAF, Flask) | `192.168.20.10` | `192.168.20.1` |
| **DB-SRV** | Serwer bazy danych (PostgreSQL) | `192.168.30.10` | `192.168.30.1` |