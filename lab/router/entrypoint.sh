#!/bin/bash
. /usr/local/lib/p02/lib.sh
log "ROUTER: start"
cfg_if eth0 192.168.10.1/24
cfg_if eth1 192.168.20.1/24
cfg_if eth2 192.168.30.1/24
sysctl -w net.ipv4.ip_forward=1 >/dev/null && log "ip_forward=1"
nft -f /etc/router-nftables.conf && log "nftables zaladowane (polityka forward = drop)"
log "ROUTER gotowy. Podglad regul: nft list ruleset"
console
