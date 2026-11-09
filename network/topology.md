# Diagram Architektury Sieci

```mermaid
flowchart TD
    %% Definicja Routera
    ROUTER(("🌐 Router<br>(3 interfejsy)"))

    %% Sieć Klienta
    subgraph CLIENT_NET ["CLIENT-NET (192.168.10.0/24)"]
        CLIENT["💻 Klient testowy<br>192.168.10.10"]
    end

    %% Strefa DMZ
    subgraph DMZ ["DMZ (192.168.20.0/24)"]
        subgraph APP_SRV ["APP-SRV (192.168.20.10)"]
            WAF["🛡️ Nginx + WAF"]
            FLASK["⚙️ Aplikacja Flask"]
            APP_LOGS[/"🗄️ Logi WAF/Audit"/]
            WAF --> FLASK
            WAF -.-> APP_LOGS
        end
    end

    %% Sieć Bazy Danych
    subgraph DB_NET ["DB-NET (192.168.30.0/24)"]
        subgraph DB_SRV ["DB-SRV (192.168.30.10)"]
            DB["🐘 PostgreSQL"]
            DB_LOGS[/"🗄️ Logi PostgreSQL/Audit"/]
            DB -.-> DB_LOGS
        end
    end

    %% Połączenia sieciowe z węzłów wewnętrznych do Routera
    CLIENT <-->|"CLIENT-NET"| ROUTER
    APP_SRV <-->|"DMZ"| ROUTER
    DB_SRV <-->|"DB-NET"| ROUTER

    %% Ruch dozwolony i blokowany (logiczny)
    CLIENT -- "✅ HTTPS (TCP/443)" --> APP_SRV
    CLIENT -. "❌ SSH (TCP/22) BLOKADA" .-> APP_SRV
    APP_SRV -- "✅ DB (TCP/5432)" --> DB_SRV