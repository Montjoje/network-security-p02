FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash curl openssl iproute2 iputils-ping netcat-openbsd procps ca-certificates coreutils \
 && rm -rf /var/lib/apt/lists/*
COPY lab/common/lib.sh /usr/local/lib/p02/lib.sh
COPY tests/ /opt/p02/tests/
COPY lab/client/entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/lib/p02/lib.sh /entrypoint.sh /opt/p02/tests/*.sh \
 && chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
