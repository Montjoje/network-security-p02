\# Diagram Architektury Sieci



```mermaid

graph TD

&#x20;   CLIENT\[Klient testowy<br>192.168.10.10] ---|CLIENT-NET<br>192.168.10.0/24| ROUTER((Router))

&#x20;   ROUTER ---|DMZ<br>192.168.20.0/24| APP\[APP-SRV<br>192.168.20.10]

&#x20;   ROUTER ---|DB-NET<br>192.168.30.0/24| DB\[DB-SRV<br>192.168.30.10]

