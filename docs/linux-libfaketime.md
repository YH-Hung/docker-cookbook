# Ubuntu and Debian with libfaketime

These recipes provide small Ubuntu and Debian images for local development and repeatable tests that need timezone configuration and process-level timestamp mocking.

## Recipes

- Ubuntu image: `images/ubuntu-libfaketime`
- Ubuntu Compose example: `compose/ubuntu-libfaketime`
- Debian image: `images/debian-libfaketime`
- Debian Compose example: `compose/debian-libfaketime`

## Timezone

Set `TZ` to an IANA timezone name:

```bash
TZ=Asia/Taipei
```

At container start, the wrapper:

1. Exports `TZ`.
2. Updates `/etc/localtime` when `/usr/share/zoneinfo/$TZ` exists.
3. Writes `/etc/timezone`.
4. Executes the requested command.

If the timezone file is missing, the wrapper prints a warning and still exports `TZ`.

## libfaketime

`libfaketime` is installed from the Ubuntu or Debian package repository. The package installs the shared library in an architecture-specific path, so each Dockerfile discovers that file during the image build and exposes it through `LIBFAKETIME_PATH=/usr/local/lib/libfaketime.so.1`.

The wrapper enables `LD_PRELOAD` only when one of these is set:

- `FAKETIME`
- `FAKETIME_TIMESTAMP_FILE`
- `FAKETIME_FOLLOW_FILE`

This keeps default container behavior close to the upstream base image.

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

`libfaketime` affects processes that inherit `LD_PRELOAD`. It does not change the Docker host clock, the kernel clock, or processes that opt out of dynamic preloading.

## Smoke Checks

Run the image smoke checks before relying on faketime in a target Docker runtime:

```bash
docker run --rm --entrypoint smoke-libfaketime.sh docker-cookbook/ubuntu-libfaketime:24.04
docker run --rm --entrypoint smoke-libfaketime.sh docker-cookbook/debian-libfaketime:12
```

The smoke check runs `date` and a small Python process with `LD_PRELOAD` and expects both to report `2024-01-02`. If it times out or reports the real date, faketime is not expected to work in that environment.
