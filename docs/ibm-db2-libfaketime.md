# IBM Db2 with libfaketime

This recipe builds a local development image on top of IBM Db2 Community Edition and adds timezone and libfaketime controls.

## Upstream Image

The Dockerfile uses `icr.io/db2_community/db2:11.5.9.0` by default. IBM's older `ibmcom/db2` Docker Hub repository notes that the image moved to IBM Container Registry.

The recipe defaults to `linux/amd64` through `DB2_PLATFORM` because the pinned Db2 image does not publish manifests for every local Docker host architecture.

IBM's Db2 container expects these common runtime settings:

- `LICENSE=accept`
- `DB2INSTANCE=db2inst1`
- `DB2INST1_PASSWORD=<password>`
- `DBNAME=<database-name>`
- `--privileged=true`
- port `50000`
- persistent storage mounted at `/database`

## Timezone

Set `TZ` to an IANA timezone name:

```bash
TZ=Asia/Taipei
```

At container start, the wrapper:

1. Exports `TZ`.
2. Updates `/etc/localtime` when `/usr/share/zoneinfo/$TZ` exists.
3. Writes `/etc/timezone`.
4. Executes IBM's original Db2 entrypoint.

If the timezone file is missing, the wrapper prints a warning and still exports `TZ`.

## libfaketime

libfaketime is built from the pinned upstream release tag `v0.9.12` during the image build.
The default build uses `LIBFAKETIME_COMPILE_CFLAGS="-DFORCE_MONOTONIC_FIX -DFORCE_PTHREAD_NONVER"` to avoid clock-related hangs seen when running the amd64 image through Docker Desktop emulation.
Even with those flags, libfaketime can still hang under Apple Silicon `linux/amd64` emulation. Verify faketime behavior on the same target architecture where you will use it; native Linux amd64 is the safest target for faketime testing with this Db2 base image.

The wrapper enables `LD_PRELOAD` only when one of these is set:

- `FAKETIME`
- `FAKETIME_TIMESTAMP_FILE`
- `FAKETIME_FOLLOW_FILE`

This keeps default Db2 startup as close to IBM's original image as possible.

Common examples:

```bash
FAKETIME="@2024-01-02 03:04:05"
FAKETIME="+2d"
FAKETIME_NO_CACHE=1
FAKETIME_DONT_FAKE_MONOTONIC=1
FAKETIME_START_AFTER_SECONDS=60
FAKETIME_STOP_AFTER_SECONDS=300
FAKETIME_DISABLE_SHM=1
```

Faking time for Db2 is useful for local test scenarios, but it can affect logs, certificates, background jobs, retention behavior, and database diagnostics. Do not use this recipe for production workloads.

## Compose Usage

```bash
cp compose/db2-libfaketime/.env.example compose/db2-libfaketime/.env
docker compose --env-file compose/db2-libfaketime/.env -f compose/db2-libfaketime/compose.yaml up -d --build
docker logs -f db2-libfaketime
```

For a manual image build that Compose can reuse on Apple Silicon Docker Desktop:

```bash
docker build --platform linux/amd64 --provenance=false -t docker-cookbook/db2-libfaketime:11.5.9.0 images/db2-libfaketime
```

To test timezone behavior:

```bash
TZ=Asia/Taipei docker compose -f compose/db2-libfaketime/compose.yaml up -d --build
docker exec db2-libfaketime date
```

To test faketime behavior:

```bash
FAKETIME="@2024-01-02 03:04:05" docker compose -f compose/db2-libfaketime/compose.yaml run --rm db2 date
```
