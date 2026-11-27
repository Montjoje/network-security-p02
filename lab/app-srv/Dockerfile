FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      nginx libnginx-mod-http-modsecurity modsecurity-crs \
      python3 python3-flask python3-psycopg gunicorn \
      nftables openssl curl iproute2 iputils-ping procps ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN useradd --system --no-create-home --uid 10001 appuser
# aplikacja
COPY app/app.py /opt/app/app.py
COPY app/files /opt/app/files
# WAF / Nginx / ModSecurity / nftables - te same pliki co na maszynie wirtualnej
COPY waf/nginx/secure-app.conf /etc/nginx/sites-available/secure-app.conf
COPY waf/modsecurity/main.conf /etc/modsecurity/main.conf
COPY waf/modsecurity/custom-rules.conf /etc/modsecurity/custom-rules.conf
COPY waf/nftables.conf /etc/nftables.conf
COPY lab/common/lib.sh /usr/local/lib/p02/lib.sh
COPY lab/app-srv/entrypoint.sh /entrypoint.sh
COPY tests/ /opt/p02/tests/
RUN sed -i 's/\r$//' /etc/nginx/sites-available/secure-app.conf /etc/modsecurity/main.conf \
      /etc/modsecurity/custom-rules.conf /etc/nftables.conf /usr/local/lib/p02/lib.sh \
      /entrypoint.sh /opt/p02/tests/*.sh \
 && rm -f /etc/nginx/sites-enabled/default \
 && ln -sf /etc/nginx/sites-available/secure-app.conf /etc/nginx/sites-enabled/secure-app.conf \
 && chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
