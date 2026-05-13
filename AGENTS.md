# AGENTS.md

Guidance for coding agents working in this repository.

## Project Overview

This repository is a Docker cookbook for local development and repeatable test environments.
It currently contains one recipe: IBM Db2 Community Edition with timezone setup and optional
libfaketime support.

The repository is not an application monorepo. Keep changes focused on Dockerfiles,
Compose files, shell wrappers, and recipe documentation.

## Repository Layout

- `README.md`: top-level project overview and recipe index.
- `compose/`: runnable Docker Compose examples.
- `compose/db2-libfaketime/`: Compose recipe for the Db2/libfaketime container.
- `docs/`: longer recipe notes and operational caveats.
- `docs/ibm-db2-libfaketime.md`: detailed notes for the Db2/libfaketime recipe.
- `images/`: custom image recipes.
- `images/db2-libfaketime/`: Dockerfile, image README, and entrypoint wrapper.

## Current Recipe

The Db2/libfaketime recipe builds from `icr.io/db2_community/db2:11.5.9.0` by default and
adds:

- `tzdata` for container timezone configuration.
- `libfaketime` built from the pinned upstream `v0.9.12` tag.
- `scripts/entrypoint-time.sh`, which sets timezone files, conditionally enables
  `LD_PRELOAD`, then delegates to IBM's original Db2 entrypoint.

Default platform handling is intentionally `linux/amd64` because the Db2 Community image is
not available for every local host architecture.

## Common Commands

Run commands from the repository root unless noted otherwise.

```bash
cp compose/db2-libfaketime/.env.example compose/db2-libfaketime/.env
docker compose --env-file compose/db2-libfaketime/.env -f compose/db2-libfaketime/compose.yaml up -d --build
docker logs -f db2-libfaketime
```

Manual image build:

```bash
docker build \
  --platform linux/amd64 \
  --provenance=false \
  -t docker-cookbook/db2-libfaketime:11.5.9.0 \
  images/db2-libfaketime
```

Check Compose config after editing the Compose file:

```bash
docker compose --env-file compose/db2-libfaketime/.env.example -f compose/db2-libfaketime/compose.yaml config
```

Check shell syntax after editing shell scripts:

```bash
bash -n images/db2-libfaketime/scripts/entrypoint-time.sh
```

## Development Guidance

- Prefer small, recipe-scoped changes. Add new recipes under both `images/<recipe-name>/`
  and, when runnable, `compose/<recipe-name>/`.
- Keep `README.md`, `docs/<recipe>.md`, and any image-specific README consistent when
  behavior or commands change.
- Do not commit local `.env` files, Db2 runtime data, logs, or generated database state.
- Preserve IBM Db2 runtime expectations such as `LICENSE=accept`, `--privileged=true`,
  port `50000`, and persistent storage mounted at `/database` unless the requested change
  explicitly alters them.
- Keep `LD_PRELOAD` disabled by default. The entrypoint should enable libfaketime only when
  `FAKETIME`, `FAKETIME_TIMESTAMP_FILE`, or `FAKETIME_FOLLOW_FILE` is configured.
- Treat faketime changes carefully. Faking time for a database can affect logs,
  certificates, jobs, retention, diagnostics, and startup behavior.
- On Apple Silicon, assume Db2 runs through Docker Desktop `linux/amd64` emulation. Verify
  faketime behavior on the same target architecture where it will be used.
- Use `rg` for repository searches and read large files in chunks.
- Do not revert user changes or remove generated/local artifacts unless explicitly asked.

## Verification Strategy

- For Dockerfile changes, run a build when practical. If a full Db2 image build is too slow
  or requires network access, state that clearly and still run cheaper checks.
- For Compose changes, run `docker compose ... config` with `.env.example`.
- For entrypoint changes, run `bash -n` and review behavior against the documented environment
  variables.
- For documentation-only changes, verify command snippets and keep paths aligned with the
  repository layout.

## When Modifying This File

- Keep this file concise and operational.
- Prefer concrete commands and durable conventions over broad process advice.
- Update it when adding recipes, changing verification commands, or changing repository-wide
  workflow expectations.
