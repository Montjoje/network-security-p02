#!/usr/bin/env python3
"""Tworzy w GNS3 projekt labu P02 z wezlami Docker (bez KVM, bez VirtualBox).

Wymaga: dzialajacego serwera GNS3, GNS3 VM oraz obrazow zbudowanych przez lab/build.sh
(p02/router, p02/client, p02/app-srv, p02/db-srv).

Uzycie:
    python lab/gns3/create-project.py --server http://127.0.0.1:3350 [--start]
"""
import argparse
import base64
import json
import sys
import urllib.error
import urllib.request

NODES = [
    # nazwa,       obraz,            karty, x,    y
    ("Router",     "p02/router:latest",  3,    0,    0),
    ("CLIENT",     "p02/client:latest",  1, -300,    0),
    ("APP-SRV",    "p02/app-srv:latest", 1,    0,  250),
    ("DB-SRV",     "p02/db-srv:latest",  1,  300,    0),
]
# (wezel A, karta A, wezel B, karta B)
LINKS = [
    ("CLIENT",  0, "Router", 0),   # CLIENT-NET 192.168.10.0/24
    ("APP-SRV", 0, "Router", 1),   # DMZ        192.168.20.0/24
    ("DB-SRV",  0, "Router", 2),   # DB-NET     192.168.30.0/24
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--server", default="http://127.0.0.1:3350", help="adres serwera GNS3 (domyslnie lokalny)")
    ap.add_argument("--compute", default="vm", help="id compute z GNS3 VM (domyslnie: vm)")
    ap.add_argument("--name", default="p02-lab-docker", help="nazwa projektu")
    ap.add_argument("--user")
    ap.add_argument("--password")
    ap.add_argument("--start", action="store_true", help="uruchom wszystkie wezly po utworzeniu")
    a = ap.parse_args()
    base = a.server.rstrip("/") + "/v2"
    headers = {"Content-Type": "application/json"}
    if a.user:
        token = base64.b64encode(f"{a.user}:{a.password or ''}".encode()).decode()
        headers["Authorization"] = "Basic " + token

    def call(method, path, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(base + path, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            sys.exit(f"BLAD {e.code} dla {method} {path}: {e.read().decode(errors='replace')}")
        except urllib.error.URLError as e:
            sys.exit(f"Nie moge polaczyc sie z {a.server}: {e.reason}")

    computes = call("GET", "/computes")
    ids = [c["compute_id"] for c in computes]
    print("Dostepne compute:", ", ".join(ids))
    if a.compute not in ids:
        sys.exit(f"Brak compute '{a.compute}'. Wlacz GNS3 VM w Preferences > GNS3 VM, albo podaj --compute z listy.")

    for p in call("GET", "/projects"):
        if p["name"] == a.name:
            sys.exit(f"Projekt '{a.name}' juz istnieje. Usun go w GNS3 albo podaj inna nazwe: --name")

    project = call("POST", "/projects", {"name": a.name})
    pid = project["project_id"]
    print("Projekt:", a.name, pid)

    node_ids = {}
    for name, image, adapters, x, y in NODES:
        n = call("POST", f"/projects/{pid}/nodes", {
            "name": name,
            "node_type": "docker",
            "compute_id": a.compute,
            "x": x, "y": y,
            "properties": {
                "image": image,
                "adapters": adapters,
                "console_type": "telnet",
                "start_command": "",
                "environment": "",
            },
        })
        node_ids[name] = n["node_id"]
        print(f"  wezel {name} ({image}, karty: {adapters})")

    for an, ai, bn, bi in LINKS:
        call("POST", f"/projects/{pid}/links", {"nodes": [
            {"node_id": node_ids[an], "adapter_number": ai, "port_number": 0},
            {"node_id": node_ids[bn], "adapter_number": bi, "port_number": 0},
        ]})
        print(f"  lacze {an}:eth{ai} <-> {bn}:eth{bi}")

    if a.start:
        call("POST", f"/projects/{pid}/nodes/start", {})
        print("Uruchomiono wszystkie wezly.")
    print("GOTOWE. Otworz projekt w GNS3: File > Open project (lub Recent projects).")


if __name__ == "__main__":
    main()
