# Containerized Codex

This repository builds a Docker image for running Codex CLI in a repeatable Ubuntu-based development environment.

The image is intended for interactive coding sessions where the container provides the shell, common developer tools, Codex, RTK, and ICM, while Docker volumes preserve the user home directory and ICM data between runs.

## What The Image Includes

- Ubuntu 26.04 as the base operating system.
- A non-root `coder` user with passwordless `sudo`.
- `/workspace` as the default working directory.
- `zsh` as the default shell.
- Common CLI tools including `git`, `curl`, `jq`, `ripgrep`, `fd-find`, `neovim`, Python 3, and build tooling.
- Pinned release binaries for:
  - Codex CLI `0.132.0`
  - RTK `0.40.0`
  - ICM `0.10.49`

During the build, the Dockerfile selects the correct binary artifacts for `amd64` or `arm64`, installs them into `/usr/local/bin`, and checks that each tool can report its version.

## Running With Docker Compose

Build and start the container:

```bash
docker compose up -d
```

Open a shell in the running container:

```bash
docker compose exec codex zsh
```

Stop the container:

```bash
docker compose stop
```

## Persistence

The Compose setup uses:

- The `codex-home` named volume mounted at `/home/coder`
- The host ICM directory `/Users/chen/Library/Application Support/dev.icm.icm`
  bind-mounted read-write at `/home/coder/.local/share/icm`

The container uses its Linux ICM executable while reading and writing the same
ICM database as the host. Mounting the complete ICM directory also shares
SQLite's journal, WAL, and shared-memory sidecar files.

Before the main container starts, Compose runs a short `codex-volume-init` service as root to ensure `/home/coder` is owned by the `coder` user. It also initializes RTK's config and tracking database, plus the ICM SQLite database, as `coder`. This prevents tools such as RTK and ICM from failing when Docker has initialized a named volume with root-owned directories. The main `codex` service still runs as the non-root `coder` user.

The init service only initializes container-owned home, RTK, and ICM paths. It
does not mount or change ownership of the host ICM directory, which is overlaid
only in the main `codex` service.

## Direct Image Usage

You can also build and run the image without Compose:

```bash
docker build -t containerized-codex:latest .
docker run --rm -it -v "$PWD:/workspace" containerized-codex:latest
```

When run directly, the image starts an interactive `zsh` shell as the `coder` user.
