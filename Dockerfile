# Nezha dashboard for Railway: the official image, pinned by version and digest,
# plus a small start script (first-boot admin password, Railway port, exit codes).
FROM ghcr.io/nezhahq/nezha:v2.7.0@sha256:7b25a608979daf84ea69afc45d56f3c9fd79cc6819d7cd606114bc6f9a2d3de7

# UTC instead of upstream's Asia/Shanghai default; cap the Go heap below Railway's
# smallest (0.5 GB) instance so the dashboard trims memory before it is OOM-killed.
ENV TZ=UTC \
    GOMEMLIMIT=360MiB

COPY railway-start.sh /railway-start.sh
RUN chmod 755 /railway-start.sh

WORKDIR /dashboard
EXPOSE 8008
ENTRYPOINT ["/railway-start.sh"]
