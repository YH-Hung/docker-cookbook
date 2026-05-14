# Ubuntu with libfaketime

This image extends `ubuntu:24.04` with:

- `tzdata` for timezone configuration.
- The distro-packaged `libfaketime`.
- A small entrypoint wrapper that configures `TZ`, conditionally enables libfaketime, then runs the requested command.

The image is intended for local development and test scenarios. It is not a production base image.

## Build

```bash
docker build \
  --provenance=false \
  -t docker-cookbook/ubuntu-libfaketime:24.04 \
  images/ubuntu-libfaketime
```

Override the base image when needed:

```bash
docker build \
  --provenance=false \
  --build-arg UBUNTU_BASE_IMAGE=ubuntu:24.04 \
  -t docker-cookbook/ubuntu-libfaketime:24.04 \
  images/ubuntu-libfaketime
```

The Dockerfile installs Ubuntu's `libfaketime` package and discovers the architecture-specific shared library path during the build. The discovered library is exposed as `LIBFAKETIME_PATH=/usr/local/lib/libfaketime.so.1`, so runtime scripts do not need to know the Debian/Ubuntu multi-arch directory name.

## Runtime Configuration

Set `TZ` to configure both the container timezone files and the environment inherited by the started process:

```bash
TZ=Asia/Taipei
```

Set `FAKETIME` or file-based faketime settings to enable libfaketime. `LD_PRELOAD` is not set unless faketime is configured.

Examples:

```bash
FAKETIME="@2024-01-02 03:04:05"
FAKETIME="+2d"
FAKETIME_NO_CACHE=1
FAKETIME_DONT_FAKE_MONOTONIC=1
FAKETIME_TIMESTAMP_FILE=/var/lib/faketime/timestamp
FAKETIME_FOLLOW_FILE=/var/lib/faketime/timestamp
FAKETIME_START_AFTER_SECONDS=60
FAKETIME_STOP_AFTER_SECONDS=300
FAKETIME_START_AFTER_NUMCALLS=100
FAKETIME_STOP_AFTER_NUMCALLS=1000
FAKETIME_DISABLE_SHM=1
```

All libfaketime environment variables are passed through to the process. Use them carefully: faking time can affect logs, certificate checks, scheduling, cache expiry, and retention logic.

Run a command with timezone configuration:

```bash
docker run --rm \
  -e TZ=Asia/Taipei \
  docker-cookbook/ubuntu-libfaketime:24.04 \
  date '+%Y-%m-%d %H:%M:%S %Z'
```

Run a command with faketime enabled:

```bash
docker run --rm \
  -e TZ=Asia/Taipei \
  -e FAKETIME='@2024-01-02 03:04:05' \
  docker-cookbook/ubuntu-libfaketime:24.04 \
  date '+%Y-%m-%d %H:%M:%S %Z'
```

Before using the image with faketime enabled, verify that libfaketime works in the target Docker runtime:

```bash
docker run --rm \
  --entrypoint smoke-libfaketime.sh \
  docker-cookbook/ubuntu-libfaketime:24.04
```

The smoke check runs `date` and a small Python process with `LD_PRELOAD` and expects both to report `2024-01-02`. If it times out or reports the real date, commands in this image are not expected to follow faketime in that Docker/runtime environment.

## Compose Usage

```bash
cp compose/ubuntu-libfaketime/.env.example compose/ubuntu-libfaketime/.env
docker compose --env-file compose/ubuntu-libfaketime/.env -f compose/ubuntu-libfaketime/compose.yaml up -d --build
docker exec ubuntu-libfaketime date '+%Y-%m-%d %H:%M:%S %Z'
```

To test timezone behavior:

```bash
TZ=Asia/Taipei docker compose -f compose/ubuntu-libfaketime/compose.yaml up -d --build --force-recreate
docker exec ubuntu-libfaketime date '+%Y-%m-%d %H:%M:%S %Z'
```

To test faketime behavior:

```bash
FAKETIME="@2024-01-02 03:04:05" docker compose -f compose/ubuntu-libfaketime/compose.yaml up -d --build --force-recreate
docker exec ubuntu-libfaketime date '+%Y-%m-%d %H:%M:%S %Z'
docker exec -i ubuntu-libfaketime python3 - <<'PY'
import datetime

print(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
PY
```
