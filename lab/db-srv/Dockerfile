FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql nftables iproute2 iputils-ping procps ca-certificates \
 && rm -rf /var/lib/apt/lists/*
# utwardzanie DB-SRV: te same pliki co na maszynie wirtualnej
COPY database/postgresql.conf.fragment /tmp/p02-hardening.conf
COPY database/pg_hba.conf.fragment /tmp/pg_hba.conf
COPY database/nftables.conf /etc/nftables.conf
COPY database/init.sql /opt/p02/init.sql
COPY lab/common/lib.sh /usr/local/lib/p02/lib.sh
COPY lab/db-srv/entrypoint.sh /entrypoint.sh
RUN PGV="$(ls /usr/lib/postgresql | sort -V | tail -1)" \
 && sed -i 's/\r$//' /tmp/p02-hardening.conf /tmp/pg_hba.conf /etc/nftables.conf /opt/p02/init.sql /usr/local/lib/p02/lib.sh /entrypoint.sh \
 && mkdir -p "/etc/postgresql/${PGV}/main/conf.d" \
 && cp /tmp/p02-hardening.conf "/etc/postgresql/${PGV}/main/conf.d/p02-hardening.conf" \
 && cp /tmp/pg_hba.conf "/etc/postgresql/${PGV}/main/pg_hba.conf" \
 && chown -R postgres:postgres "/etc/postgresql/${PGV}/main" \
 && chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
