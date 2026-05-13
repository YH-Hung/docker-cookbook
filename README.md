# Docker Cookbook

A collection of useful custom Dockerfiles and Docker Compose configurations for local development and repeatable testing.

## Structure

```text
.
├── compose/                 # Runnable Docker Compose examples
├── docs/                    # Longer notes for individual recipes
└── images/                  # Custom image recipes
```

## Recipes

### IBM Db2 with libfaketime

The first recipe extends IBM Db2 Community Edition with timezone setup and libfaketime support:

- Image recipe: `images/db2-libfaketime`
- Compose recipe: `compose/db2-libfaketime`
- Notes: `docs/ibm-db2-libfaketime.md`

Quick start:

```bash
cp compose/db2-libfaketime/.env.example compose/db2-libfaketime/.env
docker compose --env-file compose/db2-libfaketime/.env -f compose/db2-libfaketime/compose.yaml up -d --build
docker logs -f db2-libfaketime
```

Db2 setup can take several minutes. IBM's image reports `Setup has completed` when initialization is finished.

## Git

This repository is initialized for local git usage. The `.gitignore` keeps local secrets, logs, and database runtime data out of commits.
