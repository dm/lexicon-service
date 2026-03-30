FROM alpine:3.20

RUN apk add --no-cache \
    python3 \
    py3-pip \
    bash \
    curl \
    jq \
    bind-tools \
  && pip3 install --no-cache-dir --break-system-packages \
    dns-lexicon[full]

COPY entrypoint.sh sync-records.sh ddns-update.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh \
    /usr/local/bin/sync-records.sh \
    /usr/local/bin/ddns-update.sh

RUN mkdir -p /config /data

VOLUME ["/config", "/data"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
