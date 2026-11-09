\# Diagram Architektury Sieci



```mermaid

flowchart TD

&#x20;   %% Definicje węzłów i sieci

&#x20;   CLIENT\["💻 Klient testowy<br>192.168.10.10"]

&#x20;   ROUTER(("🌐 Router<br>(3 interfejsy)"))



&#x20;   subgraph CLIENT\_NET \["CLIENT-NET (192.168.10.0/24)"]

&#x20;       CLIENT

&#x20;   end



&#x20;   subgraph DMZ \["DMZ (192.168.20.0/24)"]

&#x20;       subgraph APP\_SRV \["APP-SRV (192.168.20.10)"]

&#x20;           WAF\["🛡️ Nginx + ModSecurity WAF"]

&#x20;           FLASK\["⚙️ Aplikacja Flask"]

&#x20;           APP\_LOGS\[/"🗄️ Logi (WAF, Nginx, Audit)"/]

&#x20;           WAF --> FLASK

&#x20;           WAF -.-> APP\_LOGS

&#x20;       end

&#x20;   end



&#x20;   subgraph DB\_NET \["DB-NET (192.168.30.0/24)"]

&#x20;       subgraph DB\_SRV \["DB-SRV (192.168.30.10)"]

&#x20;           DB\["🐘 PostgreSQL"]

&#x20;           DB\_LOGS\[/"🗄️ Logi (PostgreSQL, Audit)"/]

&#x20;           DB -.-> DB\_LOGS

&#x20;       end

&#x20;   end



&#x20;   %% Relacje, ruch i blokady

&#x20;   CLIENT\_NET -- "✅ HTTPS (TCP/443)" --> ROUTER

&#x20;   CLIENT\_NET -- "❌ BLOKADA SSH (TCP/22)" -.-x ROUTER

&#x20;   ROUTER --> APP\_SRV

&#x20;   APP\_SRV -- "✅ PostgreSQL (TCP/5432)" --> DB\_SRV

```

