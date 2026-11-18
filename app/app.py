import os
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory

BASE_DIR = Path(__file__).resolve().parent
FILES_DIR = BASE_DIR / "files"

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(status="ok", service="p02-webapp")


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