# Macierz Dozwolonego Ruchu (Traffic Matrix)

Wszystkie środowiska stosują domyślną politykę **DROP** (odrzucanie całego niejawnie dozwolonego ruchu).

|Źródło|Cel|Protokół/Port|Decyzja|Uzasadnienie reguły|
|-|-|-|-|-|
|**CLIENT** (`192.168.10.10`)|**APP-SRV** (`192.168.20.10`)|TCP/443|**ZEZWÓL**|Komunikacja klienta z serwerem aplikacyjnym musi odbywać się przez bezpieczny, szyfrowany kanał HTTPS zgodnie z wymaganiami.|
|**CLIENT** (`192.168.10.10`)|**APP-SRV** (`192.168.20.10`)|TCP/80|**ZABLOKUJ**|Nieszyfrowany ruch HTTP jest zabroniony, aby zapobiec podsłuchiwaniu danych.|
|**CLIENT** (`192.168.10.10`)|**APP-SRV** (`192.168.20.10`)|TCP/22|**ZABLOKUJ**|Zdalny dostęp administracyjny (SSH) do serwera aplikacyjnego jest zablokowany zgodnie z wymogami projektu.|
|**CLIENT** (`192.168.10.10`)|**DB-SRV** (`192.168.30.10`)|Wszystkie|**ZABLOKUJ**|Sieć klientów nie może mieć bezpośredniego dostępu do bazy danych, aby chronić dane w warstwie backendu.|
|**APP-SRV** (`192.168.20.10`)|**DB-SRV** (`192.168.30.10`)|TCP/5432|**ZEZWÓL**|Serwer aplikacyjny musi mieć możliwość komunikacji z bazą PostgreSQL na dedykowanym porcie w celu zapisu i odczytu danych.|
|**APP-SRV** (`192.168.20.10`)|**DB-SRV** (`192.168.30.10`)|Inne porty|**ZABLOKUJ**|Ograniczenie komunikacji tylko do niezbędnego minimum (zasada najmniejszych uprawnień) zwiększa bezpieczeństwo serwera DB-SRV.|



