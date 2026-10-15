FROM ubuntu:26.04

# Docker BuildKit supplies this when building multi-arch images.
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Install a small development baseline for interactive OMP sessions.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        fd-find \
        git \
        jq \
        less \
        neovim \
        nodejs \
        pkg-config \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        sudo \
        tar \
        unzip \
        xz-utils \
        zsh \
    && rm -rf /var/lib/apt/lists/*

# Run sessions as a regular user, but allow sudo for container maintenance.
# Created before the toolchains so each install can chown its own files in the
# same layer; a later `chown -R` would copy every toolchain into a new layer.
RUN useradd --create-home --shell /usr/bin/zsh coder \
    && usermod --append --groups sudo coder \
    && printf 'coder ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder \
    && mkdir -p /home/coder/.config /home/coder/.cache \
    && chown -R coder:coder /home/coder \
    && mkdir -p /workspace \
    && chown coder:coder /workspace

# Install current stable Rust and Go releases at build time, not distro versions.
# Keep rustup's toolchains in the image but writable by coder, so
# `rust-toolchain.toml` and `rustup component add` work. Cargo's package cache
# and `cargo install` binaries stay in the coder user's home volume.
ENV RUSTUP_HOME=/opt/rustup
ENV PATH=/opt/cargo/bin:/home/coder/.cargo/bin:/usr/local/go/bin:${PATH}
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) rust_arch="x86_64-unknown-linux-gnu" ;; \
      arm64) rust_arch="aarch64-unknown-linux-gnu" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSLo /tmp/rustup-init "https://static.rust-lang.org/rustup/dist/${rust_arch}/rustup-init"; \
    chmod +x /tmp/rustup-init; \
    CARGO_HOME=/opt/cargo /tmp/rustup-init -y --no-modify-path --profile minimal --component rustfmt,clippy --default-toolchain stable; \
    rm /tmp/rustup-init; \
    chown -R coder:coder /opt/rustup /opt/cargo; \
    rustc --version; \
    cargo --version; \
    cargo fmt --version; \
    cargo clippy --version
RUN set -eux; \
    curl -fsSLo /tmp/go-releases.json "https://go.dev/dl/?mode=json"; \
    go_release="$(jq -r --arg arch "${TARGETARCH}" 'first(.[] | select(.stable) | .files[] | select(.os == "linux" and .arch == $arch and .kind == "archive") | "\(.filename) \(.sha256)")' /tmp/go-releases.json)"; \
    test -n "${go_release}"; \
    set -- ${go_release}; \
    test "$#" -eq 2; \
    curl -fsSLo /tmp/go.tar.gz "https://go.dev/dl/$1"; \
    printf '%s  %s\n' "$2" /tmp/go.tar.gz | sha256sum -c -; \
    tar -C /usr/local -xzf /tmp/go.tar.gz; \
    rm /tmp/go-releases.json /tmp/go.tar.gz; \
    go version

# Lean native builds link against GMP; Foundry stays outside the volume-mounted
# user home so the volume does not hide it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgmp-dev zstd \
    && rm -rf /var/lib/apt/lists/*

# Bake only the elan binaries. A Lean toolchain is about 3 GB unpacked and
# projects pin their own in `lean-toolchain`, so elan downloads toolchains on
# first use into ELAN_HOME in the home volume, where they survive recreation.
ENV ELAN_HOME=/home/coder/.elan
ENV FOUNDRY_DIR=/opt/foundry
ENV PATH=/opt/elan/bin:/opt/foundry/bin:${PATH}
RUN set -eux; \
    curl -fsSLo /tmp/elan-init.sh "https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh"; \
    ELAN_HOME=/opt/elan sh /tmp/elan-init.sh -y --no-modify-path --default-toolchain none; \
    rm /tmp/elan-init.sh; \
    elan --version
RUN set -eux; \
    curl -fsSLo /tmp/foundryup-init.sh "https://raw.githubusercontent.com/foundry-rs/foundryup/HEAD/foundryup-init.sh"; \
    sh /tmp/foundryup-init.sh -y; \
    rm /tmp/foundryup-init.sh; \
    foundryup; \
    forge --version; \
    cast --version; \
    anvil --version; \
    chisel --version; \
    chown -R coder:coder /opt/foundry

# Pin CLI tool versions so rebuilds are reproducible. Declared after the
# toolchain layers because every later RUN sees these ARGs, so bumping one
# above them would rebuild and silently upgrade Rust, Go, Lean, and Foundry.
# OMP binaries are published per build ID; take the ID and checksums from
# https://build.stencil.so/api/products/omp/latest/linux-arm64?channel=stable
ARG OMP_BUILD=20261011-111043-a4d6f0a
ARG OMP_SHA256_AMD64=0ac24a7c146dbfb4005ef00e21aa60bf9b1ddf15dae5f92938542c1475824417
ARG OMP_SHA256_ARM64=8d67b1d1c8e698a8fa568685cab72b05a13263b45192e334fb5e1d04bb7dde83
ARG BUN_VERSION=1.4.2
ARG GH_VERSION=2.102.0
ARG RTK_VERSION=0.49.0

# Download pinned OMP, Bun, GitHub CLI, and RTK binaries for the target
# architecture. OMP shells out to `bun` to install plugins, and pstack's
# scripts use `node`, `bun`, and `gh`.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) \
        omp_arch="x64"; \
        omp_sha256="${OMP_SHA256_AMD64}"; \
        bun_arch="x64"; \
        gh_arch="amd64"; \
        rtk_arch="x86_64-unknown-linux-musl"; \
        ;; \
      arm64) \
        omp_arch="arm64"; \
        omp_sha256="${OMP_SHA256_ARM64}"; \
        bun_arch="aarch64"; \
        gh_arch="arm64"; \
        rtk_arch="aarch64-unknown-linux-gnu"; \
        ;; \
      *) \
        echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; \
        exit 1; \
        ;; \
    esac; \
    tmpdir="$(mktemp -d)"; \
    cd "${tmpdir}"; \
    curl -fsSLo omp "https://build.stencil.so/d/omp/${OMP_BUILD}/omp-linux-${omp_arch}"; \
    printf '%s  omp\n' "${omp_sha256}" | sha256sum -c -; \
    install -m 0755 omp /usr/local/bin/omp; \
    bun_zip="bun-linux-${bun_arch}.zip"; \
    curl -fsSLO "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/${bun_zip}"; \
    curl -fsSLO "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/SHASUMS256.txt"; \
    grep " ${bun_zip}\$" SHASUMS256.txt | sha256sum -c -; \
    unzip -q "${bun_zip}"; \
    install -m 0755 "bun-linux-${bun_arch}/bun" /usr/local/bin/bun; \
    gh_tar="gh_${GH_VERSION}_linux_${gh_arch}.tar.gz"; \
    curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${gh_tar}"; \
    curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt"; \
    grep " ${gh_tar}\$" "gh_${GH_VERSION}_checksums.txt" | sha256sum -c -; \
    tar -xzf "${gh_tar}"; \
    install -m 0755 "gh_${GH_VERSION}_linux_${gh_arch}/bin/gh" /usr/local/bin/gh; \
    curl -fsSLo rtk.tar.gz "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${rtk_arch}.tar.gz"; \
    tar -xzf rtk.tar.gz; \
    install -m 0755 rtk /usr/local/bin/rtk; \
    cd /; \
    rm -rf "${tmpdir}"; \
    omp --version; \
    bun --version; \
    node --version; \
    gh --version; \
    rtk --version

COPY docker-volume-init.sh /usr/local/bin/docker-volume-init
RUN chmod 0755 /usr/local/bin/docker-volume-init

# Drop privileges for normal use.
USER coder
WORKDIR /workspace

ENV SHELL=/usr/bin/zsh
ENV TERM=xterm-256color

# Start an interactive shell when the image is run directly.
CMD ["zsh"]
