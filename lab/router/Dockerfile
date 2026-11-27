FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update \
 && apt-get install -y --no-install-recommends nftables iproute2 iputils-ping tcpdump procps ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY lab/common/lib.sh /usr/local/lib/p02/lib.sh
COPY lab/router/nftables.conf /etc/router-nftables.conf
COPY lab/router/entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/lib/p02/lib.sh /etc/router-nftables.conf /entrypoint.sh \
 && chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
