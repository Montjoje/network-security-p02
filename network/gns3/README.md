# Projekt GNS3 – topologia laboratorium

Ten katalog zawiera **tekstową** wersję projektu GNS3 (`project.gns3`) oraz konfiguracje interfejsów z obrazów dysków, z których odczytano stan.
Obrazy dysków (`*.qcow2`) **nie trafiają do repozytorium** (patrz `docs/Instrukcja_AI_projekt_P02_4_osoby.md`, sekcja 13). Pełny eksport `.gns3project` (ok. 350 MB) należy przekazać poza Gitem.

Źródło: `bekom_dziala_plus_testy.gns3project` (projekt `bekom_projekt_dzialajacy`, odczyt 2026-11-26).

## Węzły i mapowanie interfejsów

| Węzeł GNS3 | Rola w projekcie | Interfejs | Podłączony do | Adres w systemie |
|---|---|---|---|---|
| `Alpine-Router-1` | Router (3 segmenty) | `eth0` (adapter 0) | CLIENT-NET | `192.168.10.1/24` |
| | | `eth1` (adapter 1) | DMZ (APP-SRV) | `192.168.20.1/24` |
| | | `eth2` (adapter 2) | DB-NET (DB-SRV) | `192.168.30.1/24` |
| `client` | Klient testowy | `eth0` | Router `eth0` | `192.168.10.10/24`, brama `192.168.10.1` |
| `app-server` | APP-SRV | `eth0` | Router `eth1` | `192.168.20.10/24`, brama `192.168.20.1` |
| `db-server` | DB-SRV | `eth0` | Router `eth2` | `192.168.30.10/24`, brama `192.168.30.1` |

Pozostałe adaptery (`eth1` na `app-server`, `db-server`, `client`) są podłączone do węzłów `NAT2`, `NAT3`, `NAT4`. **Nie są skonfigurowane w systemie.** Służą wyłącznie do instalacji pakietów w fazie przygotowania. Po zakończeniu przygotowania należy je odłączyć, aby hosty nie miały wyjścia do internetu (patrz `HANDOVER.md`).

## Zawartość katalogu

```text
network/gns3/
├── README.md                              ten plik
├── project.gns3                           opis projektu GNS3 (JSON, bez obrazów)
├── router/etc/network/interfaces          adresy routera
├── router/etc/nftables.nft                filtrowanie między segmentami
├── router/etc/sysctl.conf                 net.ipv4.ip_forward=1
├── app-server/etc/network/interfaces      adres APP-SRV
├── db-server/etc/network/interfaces       adres DB-SRV
└── client/etc/network/interfaces          adres klienta
```

## Reguły routera (zgodne z `network/traffic-matrix.md`)

- `forward` z polityką `drop`.
- Klient → APP-SRV: `TCP/443` zezwolone. `TCP/80` i `TCP/22` zablokowane i logowane (`DROP client-APP`).
- APP-SRV → DB-SRV: `TCP/5432` zezwolone.
- Klient → DB-SRV: `TCP/5432` zablokowane i logowane (`DROP client-DB`).

Składnię pliku sprawdzono poleceniem `nft -c -f router/etc/nftables.nft`, wynik poprawny.

## Stan hostów w obrazach (ustalone 2026-11-26)

- Wszystkie hosty działają na **Alpine Linux 3.24**. Wymagania projektu mówią o Debianie 13 (patrz `HANDOVER.md`, punkt 1).
- `app-server` i `db-server` nie mają zainstalowanych usług projektu: brak Nginx, ModSecurity, PostgreSQL, Docker i nftables. Pakiety w `/etc/apk/world`: tylko podstawowe narzędzia i OpenSSH.
- Na `app-server`, `db-server` i `client` usługa `sshd` jest włączona w runlevel `default`. Na `app-server` trzeba ją wyłączyć (wymaganie blokady SSH).
- Każdy host ma w `/root/network-tests.sh` ten sam skrypt testów sieci (identyczny skrót MD5). Jego wersja jest w `tests/network-tests.sh`.

## Odtworzenie topologii w GNS3

1. Przygotuj obraz bazowy Alpine w GNS3 (nazwa pliku z projektu: `empty8G.qcow2`). Jeśli nie masz obrazu, użyj pełnego eksportu `.gns3project` od autora projektu.
2. Dodaj cztery maszyny QEMU: router (3 adaptery, 512 MB RAM, 1 CPU), `app-server`, `db-server`, `client` (każda 2 adaptery, 512 MB RAM, 1 CPU).
3. Dodaj trzy węzły typu NAT (`NAT2`, `NAT3`, `NAT4`) i podłącz je do `eth1` hostów `app-server`, `db-server`, `client`.
4. Połącz kable zgodnie z tabelą powyżej.
5. Uruchom maszyny. W każdej wgraj odpowiedni plik `interfaces` z tego katalogu i zrestartuj sieć lub maszynę.
6. Na routerze wgraj `router/etc/nftables.nft` jako `/etc/nftables.nft` i włącz `nftables` (`rc-update add nftables default`).
7. Sprawdź adresację poleceniem `ip -4 addr` oraz `ping -c 1` do każdej bramy.

## Testy sieci

Na każdym hoście, jako root:

```sh
sh /root/network-tests.sh client   # na kliencie
sh /root/network-tests.sh app      # na APP-SRV
sh /root/network-tests.sh db       # na DB-SRV
```

Skrypt kończy się kodem 0, gdy wszystkie testy przejdą. Jest ta sama wersja w `tests/network-tests.sh`.
