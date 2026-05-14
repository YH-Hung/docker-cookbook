# Debian with libfaketime

This image extends `debian:12-slim` with:

- `tzdata` for timezone configuration.
- The distro-packaged `libfaketime`.
- A small entrypoint wrapper that configures `TZ`, conditionally enables libfaketime, then runs the requested command.

The image is intended for local development and test scenarios. It is not a production base image.

## Build

```bash
docker build \
  --provenance=false \
  -t docker-cookbook/debian-libfaketime:12 \
  images/debian-libfaketime
```

Override the base image when needed:

```bash
docker build \
  --provenance=false \
  --build-arg DEBIAN_BASE_IMAGE=debian:12-slim \
  -t docker-cookbook/debian-libfaketime:12 \
  images/debian-libfaketime
```

The Dockerfile installs Debian's `libfaketime` package and discovers the architecture-specific shared library path during the build. The discovered library is exposed as `LIBFAKETIME_PATH=/usr/local/lib/libfaketime.so.1`, so runtime scripts do not need to know the Debian multi-arch directory name.

## Runtime Configuration

The container starts `bash` by default unless a command is passed. It uses real system time unless faketime is explicitly configured.
Set `TZ` for timezone-only testing, or set one of `FAKETIME`, `FAKETIME_TIMESTAMP_FILE`, or `FAKETIME_FOLLOW_FILE` to enable libfaketime. The wrapper does not set `LD_PRELOAD` for normal runs.

### Practical Scenarios

Timezone-only local development:

```bash
TZ=Asia/Taipei
```

Use this when the command should run in a specific IANA timezone without changing the system clock. This updates `/etc/localtime`, writes `/etc/timezone`, and exports `TZ` for the started process.

Reproduce an end-of-day or end-of-month bug:

```bash
TZ=Asia/Taipei
FAKETIME="@2024-06-30 23:55:00"
FAKETIME_NO_CACHE=1
```

Use this for scripts, application tests, report cutoffs, billing periods, retention windows, and date formatting paths that depend on local time.

Check expiry behavior without waiting:

```bash
FAKETIME="+2d"
FAKETIME_NO_CACHE=1
```

Use relative offsets for tests that need "two days from now" behavior while still keeping the test run tied to the real clock.

Let a process warm up on real time, then fake time:

```bash
FAKETIME="@2024-01-02 03:04:05"
FAKETIME_START_AFTER_SECONDS=60
FAKETIME_NO_CACHE=1
```

Use this when process startup, dependency checks, or bootstrap code is sensitive to time manipulation but the main test should run against the fake timestamp.

Drive time from a file:

```bash
FAKETIME_TIMESTAMP_FILE=/var/lib/faketime/timestamp
FAKETIME_NO_CACHE=1
```

Use this when a test harness should update the fake timestamp between test phases. The file path must exist inside the container; add a bind mount in Compose when the timestamp should be controlled from the host.

### Configurable Options

Most users configure this recipe from `compose/debian-libfaketime/.env`.
Start with these values, then expand the groups below when you need deeper control:

```dotenv
DEBIAN_BASE_IMAGE=debian:12-slim
DEBIAN_IMAGE_NAME=docker-cookbook/debian-libfaketime:12
DEBIAN_CONTAINER_NAME=debian-libfaketime
TZ=UTC
FAKETIME=
```

<details>
<summary><strong>Build and image</strong></summary>

- `DEBIAN_BASE_IMAGE` (default: `debian:12-slim`): Base Debian image used by the Dockerfile.
- `DEBIAN_IMAGE_NAME` (default: `docker-cookbook/debian-libfaketime:12`): Compose image name and tag.

</details>

<details>
<summary><strong>Container identity</strong></summary>

- `DEBIAN_CONTAINER_NAME` (default: `debian-libfaketime`): Compose container name.

</details>

<details>
<summary><strong>Timezone</strong></summary>

- `TZ` (default: `UTC`): IANA timezone name such as `UTC`, `Asia/Taipei`, or `America/New_York`. When the zoneinfo file exists, the wrapper updates `/etc/localtime` and `/etc/timezone`; otherwise it exports `TZ` and prints a warning.

</details>

<details>
<summary><strong>libfaketime</strong></summary>

The wrapper enables `LD_PRELOAD` only when `FAKETIME`, `FAKETIME_TIMESTAMP_FILE`, or `FAKETIME_FOLLOW_FILE` is set.

- `FAKETIME`: Main fake-time expression. Use absolute timestamps such as `@2024-01-02 03:04:05` or relative offsets such as `+2d`.
- `FAKETIME_NO_CACHE` (default: `1` in Compose): Disables libfaketime timestamp caching. The wrapper also sets this to `1` when faketime is enabled and no value was provided.
- `FAKETIME_DONT_FAKE_MONOTONIC`: Leaves monotonic clocks unfaked when set. This can help software that relies on monotonic timers.
- `FAKETIME_TIMESTAMP_FILE`: Reads the fake-time value from a file inside the container. Use a bind mount when a host test runner should update the file.
- `FAKETIME_FOLLOW_FILE`: Makes libfaketime follow a file-based clock source. The path must exist inside the container.
- `FAKETIME_START_AFTER_SECONDS`: Starts applying faketime only after this many seconds from process start.
- `FAKETIME_STOP_AFTER_SECONDS`: Stops applying faketime after this many seconds from process start.
- `FAKETIME_START_AFTER_NUMCALLS`: Starts applying faketime after this many intercepted time calls.
- `FAKETIME_STOP_AFTER_NUMCALLS`: Stops applying faketime after this many intercepted time calls.
- `FAKETIME_DISABLE_SHM`: Disables libfaketime shared-memory support when set.

</details>

<details>
<summary><strong>Advanced wrapper and smoke test</strong></summary>

- `LIBFAKETIME_PATH` (default: `/usr/local/lib/libfaketime.so.1`): Shared library loaded through `LD_PRELOAD`.
- `LIBFAKETIME_SMOKE_TIMEOUT_SECONDS` (default: `10`): Timeout used by `smoke-libfaketime.sh`.
- `LIBFAKETIME_SMOKE_EXPECTED_PREFIX` (default: `2024-01-02`): Date prefix expected by `smoke-libfaketime.sh`.

</details>

Run a command with timezone configuration:

```bash
docker run --rm \
  -e TZ=Asia/Taipei \
  docker-cookbook/debian-libfaketime:12 \
  date '+%Y-%m-%d %H:%M:%S %Z'
```

Run a command with faketime enabled:

```bash
docker run --rm \
  -e TZ=Asia/Taipei \
  -e FAKETIME='@2024-01-02 03:04:05' \
  docker-cookbook/debian-libfaketime:12 \
  date '+%Y-%m-%d %H:%M:%S %Z'
```

Before using the image with faketime enabled, verify that libfaketime works in the target Docker runtime:

```bash
docker run --rm \
  --entrypoint smoke-libfaketime.sh \
  docker-cookbook/debian-libfaketime:12
```

The smoke check runs `date` and a small Python process with `LD_PRELOAD` and expects both to report `2024-01-02`.
Use faketime carefully: faking time can affect logs, certificate checks, scheduling, cache expiry, retention logic, diagnostics, and test cleanup. Verify behavior on the same target architecture where you will use it. If the smoke check times out or reports the real date, commands in this image are not expected to follow faketime in that Docker/runtime environment.

## Compose Usage

```bash
cp compose/debian-libfaketime/.env.example compose/debian-libfaketime/.env
docker compose --env-file compose/debian-libfaketime/.env -f compose/debian-libfaketime/compose.yaml up -d --build
docker exec debian-libfaketime date '+%Y-%m-%d %H:%M:%S %Z'
```

To test timezone behavior:

```bash
TZ=Asia/Taipei docker compose -f compose/debian-libfaketime/compose.yaml up -d --build --force-recreate
docker exec debian-libfaketime date '+%Y-%m-%d %H:%M:%S %Z'
```

To test faketime behavior:

```bash
FAKETIME="@2024-01-02 03:04:05" docker compose -f compose/debian-libfaketime/compose.yaml up -d --build --force-recreate
docker exec debian-libfaketime date '+%Y-%m-%d %H:%M:%S %Z'
docker exec -i debian-libfaketime python3 - <<'PY'
import datetime

print(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
PY
```
