ARG DB2_BASE_IMAGE=icr.io/db2_community/db2:11.5.9.0
ARG DB2_PLATFORM=linux/amd64
FROM --platform=${DB2_PLATFORM} ${DB2_BASE_IMAGE}

ARG LIBFAKETIME_VERSION=v0.9.12
ARG LIBFAKETIME_COMPILE_CFLAGS="-DFORCE_MONOTONIC_FIX -DFORCE_PTHREAD_NONVER"

USER root

RUN set -eux; \
    if command -v microdnf >/dev/null 2>&1; then \
      microdnf --disablerepo=baseos --disablerepo=appstream --disablerepo=extras install -y gcc make tar gzip tzdata findutils curl ca-certificates; \
      microdnf clean all; \
    elif command -v dnf >/dev/null 2>&1; then \
      dnf --disablerepo=baseos --disablerepo=appstream --disablerepo=extras install -y gcc make tar gzip tzdata findutils curl ca-certificates; \
      dnf clean all; \
    elif command -v yum >/dev/null 2>&1; then \
      yum --disablerepo=baseos --disablerepo=appstream --disablerepo=extras install -y gcc make tar gzip tzdata findutils curl ca-certificates; \
      yum clean all; \
    else \
      echo "No supported package manager found" >&2; \
      exit 1; \
    fi; \
    mkdir -p /tmp/libfaketime; \
    curl -fsSL "https://github.com/wolfcw/libfaketime/archive/refs/tags/${LIBFAKETIME_VERSION}.tar.gz" \
      | tar -xz --strip-components=1 -C /tmp/libfaketime; \
    FAKETIME_COMPILE_CFLAGS="${LIBFAKETIME_COMPILE_CFLAGS}" make -C /tmp/libfaketime; \
    make -C /tmp/libfaketime install; \
    ldconfig; \
    rm -rf /tmp/libfaketime

COPY scripts/entrypoint-time.sh scripts/smoke-libfaketime.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/entrypoint-time.sh /usr/local/bin/smoke-libfaketime.sh

ENV TZ=UTC \
    DB2_ORIGINAL_ENTRYPOINT=/var/db2_setup/lib/setup_db2_instance.sh \
    LIBFAKETIME_PATH=/usr/local/lib/faketime/libfaketime.so.1

ENTRYPOINT ["/usr/local/bin/entrypoint-time.sh"]
