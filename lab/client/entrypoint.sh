#!/bin/bash
. /usr/local/lib/p02/lib.sh
log "CLIENT: start"
cfg_if eth0 192.168.10.10/24
set_gw 192.168.10.1
add_host 192.168.20.10 secure-app.lab
log "CLIENT gotowy. Testy: bash /opt/p02/tests/poc-tests.sh client"
console
