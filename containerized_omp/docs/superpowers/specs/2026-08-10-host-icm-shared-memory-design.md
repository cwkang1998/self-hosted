# Host ICM Shared Memory Design

## Goal

Make ICM inside the `codex` Compose service read and write the host machine's
existing ICM memory store so host and container sessions share memories.

## Design

The container keeps the Linux ICM executable installed by the Docker image.
Compose bind-mounts the host ICM data directory:

`/Users/chen/Library/Application Support/dev.icm.icm`

at ICM's Linux data directory:

`/home/coder/.local/share/icm`

The entire directory is mounted read-write instead of mounting only
`memories.db`. This ensures SQLite journal, WAL, and shared-memory sidecar files
are visible to ICM processes on both sides. ICM remains responsible for
concurrent-access behavior.

Only the main `codex` service receives this bind mount. The root
`codex-volume-init` service must not mount the host directory because its
recursive ownership initialization could modify host-managed files. It may
continue initializing the container-only path stored inside `codex-home`; the
host bind mount overlays that path only in the main service.

The existing `icm-data` named volume is removed because it is no longer used.
The existing `codex-home` volume and workspace bind mount remain unchanged.

## Documentation

The README will explain that Compose shares the host ICM store, while the
container still supplies its own platform-compatible ICM executable. It will
also identify the host and container paths.

## Verification

1. Render the Compose model with `docker compose config` and confirm the host
   directory resolves to a read-write bind mount at the expected target.
2. Confirm the init service has no mount of the host ICM directory.
3. If the Docker runtime is available, start the services and compare ICM topic
   or statistics output from the host and container to confirm both see the
   shared store.

## Non-goals

- Changing ICM's database implementation or concurrency behavior.
- Running the host macOS ICM binary inside the Linux container.
- Introducing a remote ICM backend.
- Making this user-specific Compose file portable to other host accounts.
