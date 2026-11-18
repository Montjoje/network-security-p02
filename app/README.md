# Aplikacja

Aplikacja Flask (Osoba 1, APP i Docker) i konfiguracja Docker.

## Endpointy

| Metoda | Ścieżka | Opis |
|---|---|---|
| GET | `/` | Zwraca 200 i JSON `{"service":"p02-webapp","status":"ok"}` |
| POST | `/message` | Zapisuje pole `content` (formularz lub JSON) w tabeli `messages`; 201 po zapisie, 400 przy braku pola |
| GET | `/file?name=...` | Zwraca plik z katalogu `app/files/`; ścieżka spoza katalogu zwraca 404 |
| GET | `/command?cmd=...` | Zwraca otrzymany tekst z `executed: false`; aplikacja nie wykonuje poleceń |

## Konfiguracja

Zmienne środowiskowe (wzór w `.env.example`): `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, opcjonalnie `APP_HOST`, `APP_PORT`.
Prawdziwe hasło nie może trafić do repozytorium.

## Lokalne uruchomienie (Windows PowerShell)

1. Lokalna baza testowa (tylko do rozwoju, nie jest to docelowy DB-SRV):

```powershell
docker run --name p02-dev-db -e POSTGRES_DB=webapp_db -e POSTGRES_USER=webapp_user -e POSTGRES_PASSWORD=HASLO_TESTOWE -p 127.0.0.1:5432:5432 -d postgres:17
docker exec -i p02-dev-db psql -U webapp_user -d webapp_db -c "CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, content TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now());"
```

2. Środowisko Pythona (z katalogu głównego repozytorium):

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r app/requirements.txt
```

3. Uruchomienie aplikacji:

```powershell
$env:DB_HOST = "127.0.0.1"
$env:DB_PASSWORD = "HASLO_TESTOWE"
python app/app.py
```

4. Test (w drugim terminalu):

```powershell
curl.exe -i http://127.0.0.1:5000/
curl.exe -i -X POST -d "content=Pierwsza wiadomosc" http://127.0.0.1:5000/message
docker exec -i p02-dev-db psql -U webapp_user -d webapp_db -c "SELECT * FROM messages;"
```

Przy integracji wystarczy ustawić `DB_HOST=192.168.30.10` i właściwe hasło.