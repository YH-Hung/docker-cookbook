#!/usr/bin/env bash
set -euo pipefail

configure_timezone() {
  local zone="${TZ:-UTC}"

  export TZ="${zone}"

  if [[ -f "/usr/share/zoneinfo/${zone}" ]]; then
    ln -snf "/usr/share/zoneinfo/${zone}" /etc/localtime
    printf '%s\n' "${zone}" > /etc/timezone
    return 0
  fi

  echo "Warning: TZ '${zone}' was not found under /usr/share/zoneinfo; exporting TZ only." >&2
}

has_faketime_config() {
  [[ -n "${FAKETIME:-}" ]] \
    || [[ -n "${FAKETIME_TIMESTAMP_FILE:-}" ]] \
    || [[ -n "${FAKETIME_FOLLOW_FILE:-}" ]]
}

configure_faketime() {
  if ! has_faketime_config; then
    return 0
  fi

  local faketime_lib="${LIBFAKETIME_PATH:-/usr/local/lib/faketime/libfaketime.so.1}"

  if [[ ! -f "${faketime_lib}" ]]; then
    echo "Error: libfaketime shared library not found at ${faketime_lib}" >&2
    exit 1
  fi

  if [[ -n "${LD_PRELOAD:-}" ]]; then
    export LD_PRELOAD="${faketime_lib}:${LD_PRELOAD}"
  else
    export LD_PRELOAD="${faketime_lib}"
  fi

  export FAKETIME_NO_CACHE="${FAKETIME_NO_CACHE:-1}"
}

main() {
  configure_timezone
  configure_faketime

  local original_entrypoint="${DB2_ORIGINAL_ENTRYPOINT:-/var/db2_setup/lib/setup_db2_instance.sh}"

  if [[ "$#" -gt 0 ]]; then
    exec "$@"
  fi

  exec "${original_entrypoint}"
}

main "$@"
