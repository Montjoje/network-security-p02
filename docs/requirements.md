# Wymagania i Kryteria Zaliczenia

Dokument zawiera zbiór wymagań projektowych oraz laboratoryjnych, stanowiących kryterium zaliczenia projektu.

## 1. Wymagania Projektowe (Projekt - 10 pkt)
Raport z architektury (Network Security Blueprint) musi zawierać:
- [ ] Diagram architektury sieci (wraz z podsieciami, routerem, APP-SRV, DB-SRV i kierunkami ruchu).
- [ ] Opis zastosowanych elementów bezpieczeństwa.
- [ ] Uzasadnienie użycia poszczególnych mechanizmów bezpieczeństwa.

## 2. Wymagania Laboratoryjne (Wdrożenie PoC)

### A. Separacja i Komunikacja (APP-SRV)
- [ ] Potwierdzenie rozdzielenia usług: APP-SRV i DB-SRV działają na dwóch odrębnych hostach.
- [ ] Komunikacja z serwerem aplikacyjnym odbywa się wyłącznie przy użyciu szyfrowania **TLS 1.3**.
- [ ] Zdalny dostęp administracyjny (SSH) do serwera aplikacyjnego (APP-SRV) jest **zablokowany** z zewnątrz.

### B. Ochrona Aplikacji (WAF na APP-SRV)
Host-based WAF (np. Nginx + ModSecurity) realizuje następujące polityki:
- [ ] **SQL Injection:** Blokowanie ataków w zapytaniach POST (np. `'OR 2>1--`).
- [ ] **Path Traversal:** Blokowanie ataków w zapytaniach GET (np. `../../../../../etc/passwd`).
- [ ] **Command Injection:** Wyłącznie logowanie ataków w zapytaniach GET (np. `ls -la`), bez obowiązku blokowania, z gwarancją niewykonania polecenia.

### C. Zabezpieczenie Bazy Danych (DB-SRV)
- [ ] Przeprowadzono utwardzanie (hardening) **wyłącznie** dla serwera bazy danych (DB-SRV).

## 3. Dokumentacja i Prezentacja (9 pkt)
- [ ] **Raport z wdrożenia PoC (4 pkt):** Dokument z opisem stworzonej sieci, konfiguracją wdrożonych zabezpieczeń, potwierdzony logami i zrzutami ekranu z testów.
- [ ] **Prezentacja (5 pkt):** Zaprezentowanie działania bezpiecznej usługi WWW podczas zajęć laboratoryjnych (uruchomione środowisko, dowód działania zabezpieczeń na żywo).