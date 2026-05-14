#!/usr/bin/env bash
set -euo pipefail

faketime_lib="${LIBFAKETIME_PATH:-/usr/local/lib/faketime/libfaketime.so.1}"
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

set +e
output="$(
  timeout "${timeout_seconds}" \
    env \
      LD_PRELOAD="${faketime_lib}" \
      FAKETIME='@2024-01-02 03:04:05' \
      FAKETIME_NO_CACHE=1 \
      python3 - <<'PY'
import datetime

print(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
PY
)"
status="$?"
set -e

if [[ "${status}" -eq 124 ]]; then
  echo "libfaketime smoke failed: command timed out after ${timeout_seconds}s" >&2
  exit 1
fi

if [[ "${status}" -ne 0 ]]; then
  echo "libfaketime smoke failed: command exited with status ${status}" >&2
  [[ -n "${output}" ]] && printf '%s\n' "${output}" >&2
  exit 1
fi

if [[ "${output}" != "${expected_prefix}"* ]]; then
  echo "libfaketime smoke failed: expected ${expected_prefix}*, got '${output}'" >&2
  exit 1
fi

printf 'libfaketime smoke passed: %s\n' "${output}"
