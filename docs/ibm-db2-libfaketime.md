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

libfaketime is installed from the Db2 base image's enabled EPEL repository during the image build.
The distro package is used because the upstream source build can hang during `LD_PRELOAD` initialization in this Db2 base image under Docker Desktop `linux/amd64` emulation.
Verify faketime behavior on the same target architecture where you will use it; native Linux amd64 remains the safest target for faketime testing with this Db2 base image.

Before starting Db2 with faketime enabled, run the image smoke check:

```bash
docker run --rm --platform linux/amd64 \
  --entrypoint smoke-libfaketime.sh \
  docker-cookbook/db2-libfaketime:11.5.9.0
```

The smoke check runs a small Python process with `LD_PRELOAD` and expects it to report `2024-01-02`. If it times out or reports the real date, Db2 faketime is not expected to work in that Docker/runtime environment.

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

Wait until the logs report setup completion before running the timestamp query.

```bash
TZ=Asia/Taipei docker compose -f compose/db2-libfaketime/compose.yaml up -d --build --force-recreate
docker logs -f db2-libfaketime

docker exec --user db2inst1 db2-libfaketime bash -lc \
  '. /database/config/db2inst1/sqllib/db2profile && printf "connect to ${DBNAME:-testdb};\nvalues current timestamp;\n" | db2 +p -tx'
```

To test faketime behavior:

Run `smoke-libfaketime.sh` first. If it passes, wait until the logs report setup completion before running the timestamp query. A one-off Compose `date` command does not prove Db2's SQL timestamp behavior because it does not query the database engine.

```bash
FAKETIME="@2024-01-02 03:04:05" docker compose -f compose/db2-libfaketime/compose.yaml up -d --build --force-recreate
docker logs -f db2-libfaketime

docker exec --user db2inst1 db2-libfaketime bash -lc \
  '. /database/config/db2inst1/sqllib/db2profile && printf "connect to ${DBNAME:-testdb};\nvalues current timestamp;\n" | db2 +p -tx'
```
