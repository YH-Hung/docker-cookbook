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

The container starts like IBM's original Db2 image unless faketime is explicitly configured.
Set `TZ` for timezone-only testing, or set one of `FAKETIME`, `FAKETIME_TIMESTAMP_FILE`, or `FAKETIME_FOLLOW_FILE` to enable libfaketime. The wrapper does not set `LD_PRELOAD` for normal Db2 runs.

### Practical Scenarios

Timezone-only local development:

```bash
TZ=Asia/Taipei
FAKETIME=
```

Use this when application code depends on Db2 session timestamps, log timestamps, or date formatting in a specific locale. This updates `/etc/localtime`, writes `/etc/timezone`, and exports `TZ` for Db2.

Reproduce an end-of-day or end-of-month bug:

```bash
TZ=Asia/Taipei
FAKETIME="@2024-06-30 23:55:00"
FAKETIME_NO_CACHE=1
```

Use this for report cutoffs, billing periods, retention windows, and code paths that compare Db2 `CURRENT TIMESTAMP` with application dates.

Check expiry behavior without waiting:

```bash
TZ=UTC
FAKETIME="+14d"
FAKETIME_NO_CACHE=1
```

Use relative offsets for tests that need "two weeks from now" behavior while still keeping the test run tied to the real clock.

Let Db2 initialize on real time, then fake time:

```bash
FAKETIME="@2024-01-02 03:04:05"
FAKETIME_START_AFTER_SECONDS=120
FAKETIME_NO_CACHE=1
```

Use this when startup or bootstrap scripts are sensitive to time manipulation but the database engine should use the fake timestamp after initialization.

Drive time from a file:

```bash
FAKETIME_TIMESTAMP_FILE=/var/lib/faketime/timestamp
FAKETIME_NO_CACHE=1
```

Use this when a test harness should update the fake timestamp between test phases. The file path must exist inside the container; add a bind mount in Compose when the timestamp should be controlled from the host.

### Configurable Options

Most users configure this recipe from `compose/db2-libfaketime/.env`.
Start with these values, then expand the groups below when you need deeper control:

```dotenv
DB2INST1_PASSWORD=change-me-in-local-env
DBNAME=testdb
DB2_HOST_PORT=50000
TZ=UTC
FAKETIME=
```

<details>
<summary><strong>Build and image</strong></summary>

- `DB2_BASE_IMAGE` (default: `icr.io/db2_community/db2:11.5.9.0`): Base Db2 image used by the Dockerfile.
- `DB2_PLATFORM` (default: `linux/amd64`): Platform used in the Dockerfile `FROM` line and Compose service.
- `DB2_IMAGE_NAME` (default: `docker-cookbook/db2-libfaketime:11.5.9.0`): Compose image name and tag.

</details>

<details>
<summary><strong>Container identity and networking</strong></summary>

- `DB2_CONTAINER_NAME` (default: `db2-libfaketime`): Compose container name.
- `DB2_HOSTNAME` (default: `db2server`): Container hostname passed to Db2.
- `DB2_HOST_PORT` (default: `50000`): Host port mapped to Db2 port `50000`.

</details>

<details>
<summary><strong>Db2 startup</strong></summary>

These values are passed through to IBM's original Db2 entrypoint.

- `LICENSE` (default: `accept`): Must be `accept` for Db2 startup.
- `DB2INSTANCE` (default: `db2inst1`): Db2 instance user.
- `DB2INST1_PASSWORD` (default: `change-me-in-local-env`): Password for the instance user. Override this in a local `.env`; do not commit real secrets.
- `DBNAME` (default: `testdb`): Initial database name.
- `BLU` (default: `false`): Enables Db2 BLU settings when supported by the upstream image.
- `ENABLE_ORACLE_COMPATIBILITY` (default: `false`): Enables Oracle compatibility mode.
- `UPDATEAVAIL` (default: `NO`): Controls Db2 update availability checks.
- `TO_CREATE_SAMPLEDB` (default: `false`): Creates the Db2 sample database when set by the upstream image.
- `REPODB` (default: `false`): Enables repository database behavior expected by the upstream image.
- `IS_OSXFS` (default: `false`): Upstream Db2 flag for macOS filesystem behavior.
- `PERSISTENT_HOME` (default: `true`): Keeps the instance home under persistent storage.
- `HADR_ENABLED` (default: `false`): Enables HADR-related startup behavior when configured.
- `ETCD_ENDPOINT`, `ETCD_USERNAME`, `ETCD_PASSWORD` (default: empty): HADR/cluster coordination settings passed through to the upstream image.

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

- `LIBFAKETIME_PATH` (default: `/usr/lib64/faketime/libfaketime.so.1`): Shared library loaded through `LD_PRELOAD`.
- `DB2_ORIGINAL_ENTRYPOINT` (default: `/var/db2_setup/lib/setup_db2_instance.sh`): IBM Db2 entrypoint delegated to when no command is passed.
- `LIBFAKETIME_SMOKE_TIMEOUT_SECONDS` (default: `10`): Timeout used by `smoke-libfaketime.sh`.
- `LIBFAKETIME_SMOKE_EXPECTED_PREFIX` (default: `2024-01-02`): Date prefix expected by `smoke-libfaketime.sh`.

</details>

Before starting Db2 with faketime enabled, verify that libfaketime works in the target Docker runtime:

```bash
docker run --rm --platform linux/amd64 \
  --entrypoint smoke-libfaketime.sh \
  docker-cookbook/db2-libfaketime:11.5.9.0
```

Use faketime carefully: faking time for a database can affect logs, certificate checks, background jobs, retention logic, and diagnostics. On Apple Silicon hosts, this recipe runs Db2 through Docker Desktop's `linux/amd64` emulation. Verify faketime behavior on the same target architecture where you will use it. If the smoke check times out or reports the real date, Db2 SQL timestamps are not expected to follow faketime in that environment.
