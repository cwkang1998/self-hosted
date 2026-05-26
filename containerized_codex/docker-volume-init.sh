#!/usr/bin/env sh
set -eu

# Docker named volumes may start as root-owned directories. Prepare the home
# tree before the non-root codex service starts.
install -d -o coder -g coder \
    /home/coder/.config/rtk \
    /home/coder/.local/share/icm \
    /home/coder/.local/share/rtk \
    /home/coder/.cache
chown -R coder:coder /home/coder

# Create RTK config and tracking database as the same user that will run RTK.
if [ ! -f /home/coder/.config/rtk/config.toml ]; then
    sudo -H -u coder rtk config --create >/dev/null
fi
sudo -H -u coder rtk proxy true >/dev/null

# Create or migrate the ICM database as the same user that will run ICM.
sudo -H -u coder icm --no-embeddings stats >/dev/null
