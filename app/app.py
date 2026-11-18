import os
from pathlib import Path

import psycopg
from flask import Flask, jsonify, request, send_from_directory

BASE_DIR = Path(__file__).resolve().parent
FILES_DIR = BASE_DIR / "files"

app = Flask(__name__)


def get_db_connection():
    return psycopg.connect(
        host=os.environ.get("DB_HOST", "127.0.0.1"),
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "webapp_db"),
        user=os.environ.get("DB_USER", "webapp_user"),
        password=os.environ.get("DB_PASSWORD", ""),
        connect_timeout=5,
    )


@app.get("/")
def index():
    return jsonify(status="ok", service="p02-webapp")


@app.post("/message")
def post_message():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        data = request.form
    content = (data.get("content") or "").strip()
    if not content:
        return jsonify(error="missing field: content"), 400
    if len(content) > 1000:
        return jsonify(error="content too long"), 400

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                # zapytanie parametryzowane: wartosc nie jest sklejana z SQL
                cur.execute(
                    "INSERT INTO messages (content) VALUES (%s) RETURNING id",
                    (content,),
                )
                new_id = cur.fetchone()[0]
    except psycopg.Error:
        app.logger.exception("Database error")
        return jsonify(error="database error"), 500

    return jsonify(id=new_id, status="saved"), 201


@app.get("/file")
def get_file():
    name = request.args.get("name", "")
    if not name:
        return jsonify(error="missing parameter: name"), 400
    # send_from_directory nie wychodzi poza FILES_DIR (path traversal -> 404)
    return send_from_directory(FILES_DIR, name)


@app.get("/command")
def command():
    cmd = request.args.get("cmd", "")
    # Aplikacja NIE wykonuje przekazanego polecenia, tylko je odnotowuje.
    return jsonify(received=cmd, executed=False)


if __name__ == "__main__":
    host = os.environ.get("APP_HOST", "127.0.0.1")
    port = int(os.environ.get("APP_PORT", "5000"))
    app.run(host=host, port=port)