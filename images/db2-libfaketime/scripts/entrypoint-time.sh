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
  local faketime_lib="${LIBFAKETIME_PATH:-/usr/local/lib/faketime/libfaketime.so.1}"
  local profile_file="/etc/profile.d/faketime.sh"

  if ! has_faketime_config; then
    rm -f "${profile_file}"
    return 0
  fi

  if [[ ! -f "${faketime_lib}" ]]; then
    echo "Error: libfaketime shared library not found at ${faketime_lib}" >&2
    exit 1
  fi

  # Shell-level LD_PRELOAD for processes exec'd directly from this shell
  if [[ -n "${LD_PRELOAD:-}" ]]; then
    export LD_PRELOAD="${faketime_lib}:${LD_PRELOAD}"
  else
    export LD_PRELOAD="${faketime_lib}"
  fi

  # IBM's setup launches db2sysc via `su - db2inst1` which creates a login
  # shell and drops the parent env. Writing LD_PRELOAD + FAKETIME to
  # /etc/profile.d gets them sourced back in for that login shell, so the
  # Db2 engine inherits them. We avoid /etc/ld.so.preload because forcing
  # libfaketime into every setup process triggers known emulation hangs.
  {
    printf '# Written by entrypoint-time.sh\n'
    printf 'export LD_PRELOAD=%q\n' "${faketime_lib}"
    for var in FAKETIME FAKETIME_NO_CACHE FAKETIME_DONT_FAKE_MONOTONIC \
               FAKETIME_TIMESTAMP_FILE FAKETIME_FOLLOW_FILE \
               FAKETIME_START_AFTER_SECONDS FAKETIME_STOP_AFTER_SECONDS \
               FAKETIME_START_AFTER_NUMCALLS FAKETIME_STOP_AFTER_NUMCALLS \
               FAKETIME_DISABLE_SHM; do
      local val="${!var:-}"
      [[ -n "${val}" ]] && printf 'export %s=%q\n' "${var}" "${val}"
    done
  } > "${profile_file}"
  chmod 0644 "${profile_file}"

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
