FROM ubuntu:26.04

# Docker BuildKit supplies this when building multi-arch images.
ARG TARGETARCH

# Pin CLI tool versions so rebuilds are reproducible.
ARG CODEX_VERSION=0.132.0
ARG RTK_VERSION=0.40.0
ARG ICM_VERSION=0.10.49

ENV DEBIAN_FRONTEND=noninteractive

# Install a small development baseline for interactive Codex sessions.
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

# Download pinned Codex, RTK, and ICM binaries for the target architecture,
# verify their checksums, and install them into the container PATH.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) \
        codex_arch="x86_64-unknown-linux-musl"; \
        codex_sha="8b64432ee4ef5b1d7d197aad4535a276bc85223f4e4163769c0e1015cda883b2"; \
        rtk_arch="x86_64-unknown-linux-musl"; \
        rtk_sha="a75d210a445874106bc16da2b4efba01d36d297afa33ec134728f2d5f42ef5af"; \
        icm_arch="x86_64-unknown-linux-gnu"; \
        icm_sha="104d0d3115f72daa9271352d5a47024b68e7322209798f58ad0fb8e143088f9e"; \
        ;; \
      arm64) \
        codex_arch="aarch64-unknown-linux-musl"; \
        codex_sha="ae80a8ffb41abfca4eba9746cd3ba90403d57b02bdbcd68455f560890ad9f440"; \
        rtk_arch="aarch64-unknown-linux-gnu"; \
        rtk_sha="1d0087ad62a182c0833c2251ac678b5e05356418d91aa57305ac51a126c9b102"; \
        icm_arch="aarch64-unknown-linux-gnu"; \
        icm_sha="614fc3281193516c5b1d5a69bb541861292a4e8d74e3362b9c9789eccd56c88e"; \
        ;; \
      *) \
        echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; \
        exit 1; \
        ;; \
    esac; \
    tmpdir="$(mktemp -d)"; \
    cd "${tmpdir}"; \
    curl -fsSLo codex.tar.gz "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${codex_arch}.tar.gz"; \
    echo "${codex_sha}  codex.tar.gz" | sha256sum -c -; \
    tar -xzf codex.tar.gz; \
    install -m 0755 "codex-${codex_arch}" /usr/local/bin/codex; \
    curl -fsSLo rtk.tar.gz "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${rtk_arch}.tar.gz"; \
    echo "${rtk_sha}  rtk.tar.gz" | sha256sum -c -; \
    tar -xzf rtk.tar.gz; \
    install -m 0755 rtk /usr/local/bin/rtk; \
    curl -fsSLo icm.tar.gz "https://github.com/rtk-ai/icm/releases/download/icm-v${ICM_VERSION}/icm-${icm_arch}.tar.gz"; \
    echo "${icm_sha}  icm.tar.gz" | sha256sum -c -; \
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
