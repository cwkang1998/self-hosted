FROM ubuntu:26.04

# Docker BuildKit supplies this when building multi-arch images.
ARG TARGETARCH

# Pin CLI tool versions so rebuilds are reproducible.
ARG CODEX_VERSION=0.147.0
ARG RTK_VERSION=0.45.0
ARG ICM_VERSION=0.10.61

ENV DEBIAN_FRONTEND=noninteractive

# Install a small development baseline for interactive Codex sessions.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bubblewrap \
        build-essential \
        ca-certificates \
        curl \
        fd-find \
        git \
        jq \
        less \
        neovim \
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
RUN useradd --create-home --shell /usr/bin/zsh coder \
    && usermod --append --groups sudo coder \
    && printf 'coder ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder \
    && mkdir -p /home/coder/.config /home/coder/.local/share/icm /home/coder/.cache \
    && chown -R coder:coder /home/coder \
    && mkdir -p /workspace \
    && chown coder:coder /workspace

COPY docker-volume-init.sh /usr/local/bin/docker-volume-init
RUN chmod 0755 /usr/local/bin/docker-volume-init

# Download pinned Codex, RTK, and ICM binaries for the target architecture and
# install them into the container PATH.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) \
        codex_arch="x86_64-unknown-linux-musl"; \
        rtk_arch="x86_64-unknown-linux-musl"; \
        icm_arch="x86_64-unknown-linux-gnu"; \
        ;; \
      arm64) \
        codex_arch="aarch64-unknown-linux-musl"; \
        rtk_arch="aarch64-unknown-linux-gnu"; \
        icm_arch="aarch64-unknown-linux-gnu"; \
        ;; \
      *) \
        echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; \
        exit 1; \
        ;; \
    esac; \
    tmpdir="$(mktemp -d)"; \
    cd "${tmpdir}"; \
    curl -fsSLo codex.tar.gz "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${codex_arch}.tar.gz"; \
    tar -xzf codex.tar.gz; \
    install -m 0755 "codex-${codex_arch}" /usr/local/bin/codex; \
    curl -fsSLo rtk.tar.gz "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${rtk_arch}.tar.gz"; \
    tar -xzf rtk.tar.gz; \
    install -m 0755 rtk /usr/local/bin/rtk; \
    curl -fsSLo icm.tar.gz "https://github.com/rtk-ai/icm/releases/download/icm-v${ICM_VERSION}/icm-${icm_arch}.tar.gz"; \
    tar -xzf icm.tar.gz; \
    install -m 0755 icm /usr/local/bin/icm; \
    cd /; \
    rm -rf "${tmpdir}"; \
    codex --version; \
    rtk --version; \
    icm --version

# Drop privileges for normal use.
USER coder
WORKDIR /workspace

ENV SHELL=/usr/bin/zsh
ENV TERM=xterm-256color

# Start an interactive shell when the image is run directly.
CMD ["zsh"]
