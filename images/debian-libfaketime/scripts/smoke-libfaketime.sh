#!/usr/bin/env bash
set -euo pipefail

faketime_lib="${LIBFAKETIME_PATH:-/usr/local/lib/libfaketime.so.1}"
timeout_seconds="${LIBFAKETIME_SMOKE_TIMEOUT_SECONDS:-10}"
expected_prefix="${LIBFAKETIME_SMOKE_EXPECTED_PREFIX:-2024-01-02}"

if [[ ! -f "${faketime_lib}" ]]; then
  echo "libfaketime smoke failed: ${faketime_lib} does not exist" >&2
  exit 1
fi

if ! command -v timeout >/dev/null 2>&1; then
  echo "libfaketime smoke failed: timeout command is not available" >&2
  exit 1
fi

run_with_faketime() {
  timeout "${timeout_seconds}" \
    env \
      LD_PRELOAD="${faketime_lib}" \
      FAKETIME='@2024-01-02 03:04:05' \
      FAKETIME_NO_CACHE=1 \
      "$@"
}

check_output() {
  local label="$1"
  local output="$2"

  if [[ "${output}" != "${expected_prefix}"* ]]; then
    echo "libfaketime smoke failed: expected ${label} output ${expected_prefix}*, got '${output}'" >&2
    exit 1
  fi
}

date_output="$(run_with_faketime date '+%Y-%m-%d %H:%M:%S')"
check_output "date" "${date_output}"

python_output="$(
  run_with_faketime python3 - <<'PY'
import datetime

print(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
PY
)"
check_output "python3" "${python_output}"

printf 'libfaketime smoke passed: date=%s python3=%s\n' "${date_output}" "${python_output}"
