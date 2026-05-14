ARG DEBIAN_BASE_IMAGE=debian:12-slim
FROM ${DEBIAN_BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      coreutils \
      findutils \
      libfaketime \
      python3 \
      tzdata; \
    faketime_lib="$(find /usr/lib -path '*/faketime/libfaketime.so.1' -type f | sort | head -n 1)"; \
    if [ -z "${faketime_lib}" ]; then \
      echo "libfaketime shared library was not found" >&2; \
      exit 1; \
    fi; \
    ln -s "${faketime_lib}" /usr/local/lib/libfaketime.so.1; \
    rm -rf /var/lib/apt/lists/*

COPY scripts/entrypoint-time.sh scripts/smoke-libfaketime.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/entrypoint-time.sh /usr/local/bin/smoke-libfaketime.sh

ENV TZ=UTC \
    LIBFAKETIME_PATH=/usr/local/lib/libfaketime.so.1

ENTRYPOINT ["/usr/local/bin/entrypoint-time.sh"]
CMD ["bash"]
