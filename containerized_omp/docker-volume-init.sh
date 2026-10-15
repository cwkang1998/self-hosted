#!/usr/bin/env sh
set -eu

PSTACK_SOURCE=https://github.com/cwkang1998/pstack-omp

# Docker named volumes may start as root-owned directories. Prepare the home
# tree before the non-root omp service starts.
install -d -o coder -g coder \
    /home/coder/.config/rtk \
    /home/coder/.local/share/rtk \
    /home/coder/.cache \
    /home/coder/.elan/toolchains
chown -R coder:coder /home/coder

# Create RTK config and tracking database as the same user that will run RTK.
if [ ! -f /home/coder/.config/rtk/config.toml ]; then
    sudo -H -u coder rtk config --create >/dev/null
fi
sudo -H -u coder rtk bypass true >/dev/null

# Point elan at the stable channel once; the toolchain itself downloads on the
# first `lean` or `lake` call. Skipped later so `elan default` changes stick.
if [ ! -f /home/coder/.elan/settings.toml ]; then
    sudo -H -u coder env ELAN_HOME=/home/coder/.elan \
        /opt/elan/bin/elan default leanprover/lean4:stable >/dev/null
fi

# Install pstack only while omp's plugin lock has no registration for it;
# reinstalling would re-enable a plugin the user disabled. `omp plugin list`
# is not enough: it lists an install interrupted before registration as
# enabled, and `omp plugin disable` then fails on it.
# Update it with `omp plugin upgrade pstack-omp`.
if ! sudo -H -u coder jq -e '.plugins["pstack-omp"]' \
    /home/coder/.omp/plugins/omp-plugins.lock.json >/dev/null 2>&1; then
    sudo -H -u coder omp plugin install "${PSTACK_SOURCE}"
fi

sudo -H -u coder omp config set memory.backend local >/dev/null

# The image pins omp in a root-owned path, so `omp update` cannot succeed here.
sudo -H -u coder omp config set startup.checkUpdate false >/dev/null
