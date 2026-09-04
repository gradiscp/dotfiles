#!/bin/bash
# Bring a fresh Omarchy install up to the same config as this repo.
# Usage: run it from wherever the repo is checked out, e.g.
#   ~/Projects/paulgradischnig/dotfiles/install.sh
# (REPO_DIR below is derived from this file's own location, so the path
# does not matter - but note the symlinks it creates DO bake it in. Moving
# the repo afterwards leaves them dangling; re-run this script then.)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
STAMP="$(date +%s)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "Backing up existing $dst -> $dst.bak.$STAMP"
    mv "$dst" "$dst.bak.$STAMP"
  fi
  ln -sfn "$src" "$dst"
  echo "Linked $dst -> $src"
}

echo "== Packages =="
sudo pacman -Sy --needed --noconfirm firefox
if command -v yay >/dev/null; then
  yay -S --needed --noconfirm bibata-cursor-theme-bin
else
  echo "yay not found, skipping AUR packages (bibata-cursor-theme-bin) - install yay first."
fi
echo "(Fingerprint packages intentionally NOT installed - see CLAUDE.md, this laptop's sensor has no Linux driver.)"

echo "== Hyprland config =="
for f in "$REPO_DIR"/config/hypr/*.lua; do
  link "$f" "$CONFIG_DIR/hypr/$(basename "$f")"
done

echo "== Omarchy shell =="
link "$REPO_DIR/config/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json"
link "$REPO_DIR/config/omarchy/plugins/gradiscp.lock" "$CONFIG_DIR/omarchy/plugins/gradiscp.lock"
link "$REPO_DIR/config/omarchy/plugins/gradiscp.idle" "$CONFIG_DIR/omarchy/plugins/gradiscp.idle"
# Custom theme (whole directory, not a single file - it is not an overlay
# on a stock theme, it is its own theme). omarchy-theme-list globs both
# dirs and symlinks, so linking the directory is enough.
link "$REPO_DIR/config/omarchy/themes/crimson-core" "$CONFIG_DIR/omarchy/themes/crimson-core"

echo "== Foot terminal =="
link "$REPO_DIR/config/foot/foot.ini" "$CONFIG_DIR/foot/foot.ini"

echo "== Fontconfig (embolden JetBrains Mono) =="
link "$REPO_DIR/config/fontconfig/conf.d/51-embolden-jetbrains.conf" "$CONFIG_DIR/fontconfig/conf.d/51-embolden-jetbrains.conf"
fc-cache -f >/dev/null 2>&1 || true

echo "== Neovim =="
link "$REPO_DIR/config/nvim/lua/config/autocmds.lua" "$CONFIG_DIR/nvim/lua/config/autocmds.lua"

echo "== Scripts =="
mkdir -p "$HOME/.local/bin"
link "$REPO_DIR/bin/omarchy-lock-light" "$HOME/.local/bin/omarchy-lock-light"
link "$REPO_DIR/bin/omarchy-idle-audio-guard" "$HOME/.local/bin/omarchy-idle-audio-guard"

echo "== Systemd user services =="
# Keeps the screensaver/idle lock away while audio is playing (films, series).
# See the idle section in CLAUDE.md for why Firefox cannot do this itself.
link "$REPO_DIR/config/systemd/user/omarchy-idle-audio-guard.service" \
  "$CONFIG_DIR/systemd/user/omarchy-idle-audio-guard.service"
systemctl --user daemon-reload
systemctl --user enable --now omarchy-idle-audio-guard.service

echo "== GTK/GNOME settings =="
bash "$REPO_DIR/gsettings.sh"

echo "== App cleanup =="
bash "$REPO_DIR/remove-unwanted-apps.sh"

echo "== Reload =="
omarchy theme set crimson-core || true
omarchy restart shell || true
hyprctl reload || true

cat <<'EOF'

Done. Manual steps still needed on this machine:
  1. Review config/hypr/monitors.lua — the scale value (currently 1.0,
     native) may need adjusting for a different panel. Use
     `omarchy hyprland monitor scaling <N>`, not a raw file edit — see
     CLAUDE.md for why.
  2. Copy your SSH key into ~/.ssh (chmod 600 the private key, 644 the
     .pub) if you want git push/pull over SSH here.
  3. Fingerprint: skipped on purpose (see CLAUDE.md). If the new laptop
     has different hardware, check `libfprint`'s supported-devices list
     before bothering to set it up.
  4. Chromium is NOT installed here, only Firefox — any leftover Omarchy
     webapp shortcut (WhatsApp/Discord/YouTube/Docker) will fail to launch
     until Chromium is reinstalled (see CLAUDE.md for why).
  5. Boot/login screen — not done automatically, because it writes to
     /usr/share and rebuilds the initramfs. Run by hand:
         omarchy plymouth set by theme crimson-core
     That styles both the Plymouth LUKS unlock prompt and the SDDM
     greeter from crimson-core's colors.toml + unlock.png.
     `omarchy plymouth reset` puts the stock Omarchy one back.
EOF
