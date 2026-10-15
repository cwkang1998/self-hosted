# Host ICM Shared Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make host and container Codex sessions share the host machine's existing ICM memory store.

**Architecture:** Keep the platform-compatible Linux ICM executable in the image and bind-mount the host ICM data directory over ICM's Linux data directory in only the main `codex` service. Mount the directory rather than only the database so SQLite sidecar files are shared, while keeping the root init service away from host-managed files.

**Tech Stack:** Docker Compose, ICM, SQLite, Markdown

## Global Constraints

- Host ICM data directory: `/Users/chen/Library/Application Support/dev.icm.icm`.
- Container ICM data directory: `/home/coder/.local/share/icm`.
- The bind mount is read-write.
- ICM owns concurrent-access behavior.
- The root `codex-volume-init` service must not mount the host ICM directory.
- Preserve the existing `codex-home` volume and workspace bind mount.
- Do not alter the user's existing Dockerfile version bumps or workspace-path edits.

---

### Task 1: Share the host ICM store

**Files:**
- Modify: `compose.yml`
- Modify: `README.md`

**Interfaces:**
- Consumes: Host ICM's directory at `/Users/chen/Library/Application Support/dev.icm.icm`.
- Produces: A read-write directory bind at `/home/coder/.local/share/icm` in the `codex` service.

- [x] **Step 1: Capture the failing Compose-model checks**

Render the current Compose model:

```bash
rtk docker compose config --format json > /tmp/containerized-codex-compose-before.json
```

Verify the current model does not yet expose the required host directory. This
must exit nonzero before the edit:

```bash
rtk jq -e '
  any(.services.codex.volumes[];
    .type == "bind" and
    .source == "/Users/chen/Library/Application Support/dev.icm.icm" and
    .target == "/home/coder/.local/share/icm" and
    (.read_only // false) == false)
' /tmp/containerized-codex-compose-before.json
```

Expected: `false` and exit status 1 because `codex` still uses the `icm-data`
named volume.

- [x] **Step 2: Apply the minimal Compose change**

In `compose.yml`, remove this mount from `codex-volume-init`:

```yaml
      - icm-data:/home/coder/.local/share/icm
```

Replace the same named-volume mount under `codex` with:

```yaml
      - type: bind
        source: /Users/chen/Library/Application Support/dev.icm.icm
        target: /home/coder/.local/share/icm
```

Remove the unused declaration from the top-level `volumes` map:

```yaml
  icm-data:
```

Do not change the existing `codex-home` or workspace mounts.

- [x] **Step 3: Update the persistence documentation**

In `README.md`, replace the statement that Compose defines two named volumes
with an explanation that it defines one named home volume and one host bind:

```markdown
The Compose setup uses:

- The `codex-home` named volume mounted at `/home/coder`
- The host ICM directory `/Users/chen/Library/Application Support/dev.icm.icm`
  bind-mounted read-write at `/home/coder/.local/share/icm`

The container uses its Linux ICM executable while reading and writing the same
ICM database as the host. Mounting the complete ICM directory also shares
SQLite's journal, WAL, and shared-memory sidecar files.
```

Update the following initialization paragraph to state that
`codex-volume-init` initializes only container-owned home, RTK, and ICM paths.
State explicitly that it does not mount or change ownership of the host ICM
directory, which is overlaid only in the main `codex` service.

- [x] **Step 4: Validate the rendered Compose model**

Render the updated model:

```bash
rtk docker compose config --format json > /tmp/containerized-codex-compose-after.json
```

Confirm the main service has the exact read-write bind:

```bash
rtk jq -e '
  any(.services.codex.volumes[];
    .type == "bind" and
    .source == "/Users/chen/Library/Application Support/dev.icm.icm" and
    .target == "/home/coder/.local/share/icm" and
    (.read_only // false) == false)
' /tmp/containerized-codex-compose-after.json
```

Expected: `true` and exit status 0.

Confirm the init service cannot see the host ICM directory:

```bash
rtk jq -e '
  all(.services["codex-volume-init"].volumes[];
    .source != "/Users/chen/Library/Application Support/dev.icm.icm" and
    .target != "/home/coder/.local/share/icm")
' /tmp/containerized-codex-compose-after.json
```

Expected: `true` and exit status 0.

Confirm no `icm-data` named volume remains:

```bash
rtk jq -e '(.volumes // {}) | has("icm-data") | not' /tmp/containerized-codex-compose-after.json
```

Expected: `true` and exit status 0.

- [x] **Step 5: Verify live shared-memory visibility when Docker is available**

Start or recreate the services:

```bash
rtk docker compose up -d
```

Read host and container statistics without mutating access bookkeeping:

```bash
rtk icm --read-only stats
rtk docker compose exec codex icm --read-only stats
```

Expected: Both commands succeed against the same database and report the same
memory and topic totals. If Docker Desktop denies access to the host directory,
report that runtime permission error without changing the mount design.

- [x] **Step 6: Check the final diff without staging the user's changes**

```bash
rtk git diff --check -- compose.yml README.md
rtk git diff -- compose.yml README.md
```

Expected: No whitespace errors; the diff contains only the approved ICM mount
and documentation changes in addition to the user's pre-existing workspace
path change in `compose.yml`. The pre-existing Dockerfile version bumps remain
unstaged and uncommitted. Leave the implementation uncommitted because the
approved change overlaps the user's existing uncommitted `compose.yml` edit;
staging the whole file would capture work outside this task.
