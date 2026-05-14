# IBM Db2 with libfaketime

This image extends `icr.io/db2_community/db2:11.5.9.0` with:

- `tzdata` for timezone configuration.
- The distro-packaged `libfaketime` from EPEL.
- A small entrypoint wrapper that configures `TZ`, conditionally enables libfaketime, then runs IBM's original Db2 entrypoint.

The image is intended for local development and test scenarios. It is not a production Db2 image.

## Build

```bash
docker build \
  --platform linux/amd64 \
  --provenance=false \
  -t docker-cookbook/db2-libfaketime:11.5.9.0 \
  images/db2-libfaketime
```

Override the base image or target platform when needed:

```bash
docker build \
  --platform linux/amd64 \
  --provenance=false \
  --build-arg DB2_BASE_IMAGE=icr.io/db2_community/db2:11.5.9.0 \
  --build-arg DB2_PLATFORM=linux/amd64 \
  -t docker-cookbook/db2-libfaketime:11.5.9.0 \
  images/db2-libfaketime
```

The default platform is `linux/amd64` because IBM Db2 Community Edition images are not published for every local Docker host architecture.
The image uses the EPEL `libfaketime` package because the upstream source build can hang during `LD_PRELOAD` initialization in this Db2 base image under Docker Desktop `linux/amd64` emulation.

## Runtime Configuration

Set `TZ` to configure both the container timezone files and the environment inherited by Db2:

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

All libfaketime environment variables are passed through to the process. Use them carefully: faking time for a database can affect logs, certificate checks, scheduling, and retention logic.

Before starting Db2 with faketime enabled, verify that libfaketime works in the target Docker runtime:

```bash
docker run --rm --platform linux/amd64 \
  --entrypoint smoke-libfaketime.sh \
  docker-cookbook/db2-libfaketime:11.5.9.0
```

On Apple Silicon hosts, this recipe runs Db2 through Docker Desktop's `linux/amd64` emulation. Verify faketime behavior on the same target architecture where you will use it. If the smoke check times out or reports the real date, Db2 SQL timestamps are not expected to follow faketime in that environment.
