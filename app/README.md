# Aplikacja

Aplikacja Flask (Osoba 1, APP i Docker) wraz z konfiguracją Docker.

## Endpointy

| Metoda | Ścieżka | Opis |
|---|---|---|
| GET | `/` | Zwraca 200 i JSON `{"service":"p02-webapp","status":"ok"}` |
| POST | `/message` | Zapisuje pole `content` (formularz lub JSON) w tabeli `messages`; 201 po zapisie, 400 przy braku pola |
| GET | `/file?name=...` | Zwraca plik z katalogu `app/files/`; ścieżka spoza katalogu zwraca 404 |
| GET | `/command?cmd=...` | Zwraca otrzymany tekst z `executed: false`; aplikacja nie wykonuje poleceń |

Zapytania SQL są parametryzowane. Aplikacja nie wykonuje poleceń systemowych.

## Konfiguracja

Zmienne środowiskowe (wzór w `.env.example`):

| Zmienna | Znaczenie |
|---|---|
| `DB_HOST`, `DB_PORT` | adres i port PostgreSQL |
| `DB_NAME`, `DB_USER` | nazwa bazy i użytkownik aplikacyjny |
| `DB_PASSWORD` | hasło (tylko w lokalnym `.env`, nie w Git) |
| `APP_HOST`, `APP_PORT` | adres i port nasłuchu (tylko przy uruchomieniu `python app/app.py`) |

Plik `.env` jest ignorowany przez Git. W repozytorium jest wyłącznie `.env.example` z wartością `CHANGE_ME`.

## Uruchomienie lokalne (Docker Compose)

Środowisko lokalne uruchamia aplikację (Gunicorn, użytkownik bez uprawnień root) i tymczasową bazę PostgreSQL wyłącznie do testów. Nie jest to docelowy DB-SRV. Aplikacja jest dostępna tylko pod `127.0.0.1:5000`.

Windows PowerShell, z katalogu `app`:

```powershell
Copy-Item .env.example .env
notepad .env
docker compose -f compose.local.yaml up -d --build
```

W `.env` ustaw tylko `DB_PASSWORD` (np. na hasło testowe). Adres bazy w kontenerze jest nadpisany na `db` w `compose.local.yaml`.

Sprawdzenie:

```powershell
docker compose -f compose.local.yaml ps
curl.exe -i http://127.0.0.1:5000/
curl.exe -i -X POST -d "content=Pierwsza wiadomosc" http://127.0.0.1:5000/message
docker compose -f compose.local.yaml exec db psql -U webapp_user -d webapp_db -c "SELECT * FROM messages;"
```

Logi i zatrzymanie:

```powershell
docker compose -f compose.local.yaml logs --tail=100
docker compose -f compose.local.yaml down       # zachowuje dane bazy
docker compose -f compose.local.yaml down -v    # usuwa też dane bazy
```

## Uruchomienie w laboratorium (APP-SRV, `compose.lab.yaml`)

Wersja dla APP-SRV uruchamia tylko aplikację i łączy się z bazą na DB-SRV. Aplikacja jest dostępna wyłącznie pod `127.0.0.1:5000`, a ruch z klienta przyjmuje Nginx (TCP/443, TLS 1.3, WAF) skonfigurowany skryptem `waf/setup-app-srv.sh`.

Na APP-SRV, z katalogu `app` (hasło wpisz interaktywnie, nie zapisuj go w historii poleceń):

```bash
umask 077
read -rsp "DB_PASSWORD: " DB_PASSWORD; echo
printf 'DB_HOST=192.168.30.10\nDB_PORT=5432\nDB_NAME=webapp_db\nDB_USER=webapp_user\nDB_PASSWORD=%s\n' "$DB_PASSWORD" > .env
unset DB_PASSWORD
sudo docker compose -f compose.lab.yaml up -d --build
```

Plik `.env` jest ignorowany przez Git. Przed zmianą środowiska zatrzymaj stary stos (`docker compose -f compose.local.yaml down -v`), żeby na APP-SRV nie działała lokalna baza.

## Testy

Z katalogu głównego repozytorium (na Windowsie w Git Bash, nie w WSL):

```bash
bash tests/app-tests.sh http://127.0.0.1:5000
```

Oczekiwany wynik: `PASS=35 FAIL=0 SKIP=0` i kod wyjścia 0. Testy bazy, kontenerów i restartu wymagają lokalnego Docker Compose, w przeciwnym razie dostają status SKIP.

## Uwagi

- Pliki konfiguracyjne (`Dockerfile`, `*.yaml`, `*.sql`, `*.sh`) zapisuj w UTF-8; skrypty `.sh` z końcami linii LF (wymusza to `.gitattributes`).
- Docelowa baza PostgreSQL działa na DB-SRV (`192.168.30.10`), a nie w lokalnym kontenerze.

## Odpowiedzialność

Osoba 1 (APP i Docker)