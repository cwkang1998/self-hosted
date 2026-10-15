# Containerized OMP

This directory builds a Docker image for running the [OMP](https://omp.sh/) coding agent in a repeatable Ubuntu-based development environment.

The image is intended for interactive coding sessions where the container provides the shell, common developer tools, OMP with the [pstack](https://github.com/cwkang1998/pstack-omp) plugin, and RTK, while a Docker volume preserves the user home directory (OMP logins, sessions, memory, and plugins) between runs.

## What The Image Includes

- Ubuntu 26.04 as the base operating system.
- A non-root `coder` user with passwordless `sudo`.
- `/workspace` as the default working directory.
- `zsh` as the default shell.
- Common CLI tools including `git`, `curl`, `jq`, `ripgrep`, `fd-find`, `neovim`, Python 3, Node.js, and build tooling.
- The latest stable Rust toolchain (via rustup, with `rustfmt` and `clippy`) and Go release available when the image is built, for `amd64` and `arm64`.
- `elan`, the Lean 4 toolchain manager. Lean toolchains (with `lean` and `lake`) download on first use into the home volume instead of being baked into the image.
- The latest stable Foundry release via `foundryup`, including `forge`, `cast`, `anvil`, and `chisel` for Solidity/EVM development.
- GMP development headers and `zstd` alongside the existing C/C++ build tools for Lean native builds and compressed dependencies.
- Pinned release binaries for:
  - OMP `18.9.1` (build `20261011-111043-a4d6f0a`)
  - Bun `1.4.2`
  - GitHub CLI `2.102.0`
  - RTK `0.49.0`

During the build, the Dockerfile selects the correct `amd64` or `arm64`
binaries, verifies OMP against the pinned SHA-256 and Bun and GitHub CLI
against their published checksum files, and checks that each tool can report
its version. OMP needs `bun` on `PATH` to install plugins; pstack's scripts use
`node`, `bun`, and `gh`.

To move to a newer OMP, read
`https://build.stencil.so/api/products/omp/latest/linux-arm64?channel=stable`.
Its `build.id` is `OMP_BUILD`, and `build.files[]` lists the SHA-256 for both
`omp-linux-arm64` (`OMP_SHA256_ARM64`) and `omp-linux-x64` (`OMP_SHA256_AMD64`).
These pins sit below the toolchain layers, so bumping them rebuilds only the
binary download step. `omp update` cannot replace the root-owned binary inside
the container, so the init service turns off OMP's startup update check.

## Running With Docker Compose

Build and start the container, refreshing Rust, Go, elan, and Foundry from upstream:

```bash
docker compose build --no-cache
docker compose up -d --no-build
```

Docker may reuse cached toolchain installation layers on normal builds. Use
`--no-cache` when you want to fetch the current stable releases.

Open a shell in the running container and start OMP:

```bash
docker compose exec omp zsh
omp
```

Log in to a model provider on first use with `/login` inside OMP or
`omp login` from the shell. Credentials live in the home volume. Run
`gh auth login` once if you use pstack's PR workflows.

OMP's default `tools.approvalMode` is `yolo`, so it runs commands and edits
files without asking. Codex's bubblewrap sandbox is gone, which leaves the
container as the only boundary. Inside it, `coder` has passwordless `sudo` and
read-write access to all of `/Users/chen/Projects`. To be asked before
commands run, set a stricter mode in the container:

```bash
omp config set tools.approvalMode write
```

Stop the container:

```bash
docker compose stop
```

## pstack And Memory

Before the main container starts, Compose runs a short `omp-volume-init`
service as root. As the `coder` user, it:

- installs pstack from `https://github.com/cwkang1998/pstack-omp` with
  `omp plugin install` when `omp plugin list` does not show it yet,
- sets `memory.backend` to `local` in `~/.omp/agent/config.yml`, and
- sets `startup.checkUpdate` to `false`.

The pstack install needs network access on the first start of a fresh volume.
If it fails, the init service exits non-zero and the `omp` service does not
start. Later starts skip the install, so disabling the plugin with
`omp plugin disable pstack-omp` sticks. An install interrupted before omp
registered the plugin is retried on the next start. Update pstack inside the
container:

```bash
omp plugin upgrade pstack-omp
```

The memory backend is reapplied on every start, so it stays `local` even if
it is changed inside the container. Local memory is stored under
`~/.omp/agent/memories` in the home volume and is not shared with the host.

## Lean And Smart Contracts

Rust and Foundry are installed in `/opt/rustup` and `/opt/cargo`, and
`/opt/foundry`, with their binaries on `PATH`. These directories are writable
by `coder`, so `rustup` honors `rust-toolchain.toml`, and mounting the home
volume does not hide the image's toolchains. Extra Rust toolchains installed
there are container-local and must be reinstalled after recreating the
container. Cargo's registry cache and `cargo install` binaries live in
`~/.cargo` in the home volume, and `~/.cargo/bin` is on `PATH`.

Lean is different. A Lean toolchain is about 3 GB unpacked, and projects pin
their own version in `lean-toolchain`, so the image ships only the `elan`
binaries in `/opt/elan/bin`. Toolchains live in `~/.elan` (`ELAN_HOME`) in the
home volume. The init service sets the default to `leanprover/lean4:stable`
once, and the first `lean` or `lake` call downloads it (about 550 MB). Later
calls, and later containers on the same volume, reuse it. Change the default
with `elan default <toolchain>`; the init service leaves it alone afterwards.

For an existing Lean verification project, run:

```bash
lake build
```

`elan` honors the project's `lean-toolchain` file and downloads its selected
Lean version as needed. Keep proof libraries such as Mathlib in the project's
Lake dependencies rather than installing a global copy. To create a
[Mathlib-backed project](https://leanprover-community.github.io/install/project.html):

```bash
lake new contract_proofs math
cd contract_proofs
lake update
lake build
```

For an existing Foundry contract project, run:

```bash
forge build
forge test
```

Forge downloads the required Solidity compiler automatically; a global `solc`
installation is not needed. Initial compiler, Lean toolchain, and project
dependency downloads require network access. Run `anvil` for a local EVM node
and use `cast` to deploy, send transactions, or query it.

Lean supplies the proof environment; it does not automatically translate or
verify Solidity contracts. Contract models and any Solidity-to-Lean integration
belong to the verification project's dependencies.

## Persistence

The Compose setup uses:

- The `omp-home` named volume mounted at `/home/coder`
- The host `/Users/chen/Projects` directory bind-mounted at `/home/coder/workspace`

The init service ensures `/home/coder` is owned by the `coder` user,
initializes RTK's config and tracking database, and sets elan's default
toolchain, so tools do not fail when Docker has initialized a named volume with
root-owned directories. The main `omp` service runs as the non-root `coder`
user.

## Direct Image Usage

You can also build and run the image without Compose:

```bash
docker build --no-cache -t containerized-omp:latest .
docker run --rm -it -v "$PWD:/workspace" containerized-omp:latest
```

When run directly, the image starts an interactive `zsh` shell as the `coder`
user. The init script does not run, so install pstack and set the memory
backend yourself, or run `sudo docker-volume-init` once inside the container.
