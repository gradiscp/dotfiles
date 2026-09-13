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

# Print every link target that is not a symlink into this repo. Omarchy's own
# tools replace links with plain files when they write (omarchy-shell-config
# mv's over shell.json, omarchy-hyprland-monitor-scaling runs sed -i without
# --follow-symlinks), so this is worth re-running any time - see CLAUDE.md.
LINKS=()
link() {
  local src="$1" dst="$2"
  LINKS+=("$dst")
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "Backing up existing $dst -> $dst.bak.$STAMP"
    mv "$dst" "$dst.bak.$STAMP"
  fi
  ln -sfn "$src" "$dst"
  echo "Linked $dst -> $src"
}

echo "== Packages =="
# packages.txt: one name per line, "#" comments, an [aur] header switches to
# the AUR list. -S without -y: a plain -Sy refreshes the database without
# upgrading, which is the partial-upgrade trap on Arch; keep updating to
# `omarchy update`.
mapfile -t PACMAN_PKGS < <(sed -n '/^\[aur\]/q; s/#.*//; /^\s*$/d; p' "$REPO_DIR/packages.txt")
mapfile -t AUR_PKGS < <(sed -n '/^\[aur\]/,$ { /^\[aur\]/d; s/#.*//; /^\s*$/d; p }' "$REPO_DIR/packages.txt")
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
if command -v yay >/dev/null; then
  yay -S --needed --noconfirm "${AUR_PKGS[@]}"
else
  echo "yay not found, skipping AUR packages (${AUR_PKGS[*]}) - install yay first."
fi
echo "(Fingerprint packages intentionally NOT installed - see CLAUDE.md, this laptop's sensor has no Linux driver.)"

echo "== Tailscale =="
# The service and the operator right only; `sudo tailscale up` (the login) is
# interactive and stays a manual step. Omarchy's own installer also adds a
# Chromium webapp and a bar widget, neither wanted here.
sudo systemctl enable --now tailscaled.service
sudo tailscale set --operator="$USER" || true

echo "== Hyprland config =="
for f in "$REPO_DIR"/config/hypr/*.lua; do
  link "$f" "$CONFIG_DIR/hypr/$(basename "$f")"
done

echo "== Omarchy shell =="
link "$REPO_DIR/config/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json"
link "$REPO_DIR/config/omarchy/plugins/gradiscp.lock" "$CONFIG_DIR/omarchy/plugins/gradiscp.lock"
link "$REPO_DIR/config/omarchy/plugins/gradiscp.idle" "$CONFIG_DIR/omarchy/plugins/gradiscp.idle"
# SUPER+W's "close anyway?" dialog, summoned by bin/window-close-guard.
link "$REPO_DIR/config/omarchy/plugins/gradiscp.closeconfirm" "$CONFIG_DIR/omarchy/plugins/gradiscp.closeconfirm"
# Clones of omarchy.workspaces / omarchy.notifications (red pill, calmer toasts)
# and the Claude waiting-count widget. shell.json above already points the bar
# and the plugin list at these ids.
link "$REPO_DIR/config/omarchy/plugins/gradiscp.workspaces" "$CONFIG_DIR/omarchy/plugins/gradiscp.workspaces"
link "$REPO_DIR/config/omarchy/plugins/gradiscp.notifications" "$CONFIG_DIR/omarchy/plugins/gradiscp.notifications"
link "$REPO_DIR/config/omarchy/plugins/gradiscp.claude-status" "$CONFIG_DIR/omarchy/plugins/gradiscp.claude-status"
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

echo "== herdr, git, mise, default apps =="
link "$REPO_DIR/config/herdr/config.toml" "$CONFIG_DIR/herdr/config.toml"
link "$REPO_DIR/config/git/config" "$CONFIG_DIR/git/config"
link "$REPO_DIR/config/git/ignore" "$CONFIG_DIR/git/ignore"
# Tool versions for claude/codex/gh/node/pi; `mise install` fetches them.
link "$REPO_DIR/config/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
if command -v mise >/dev/null; then mise install || true; fi
# Firefox as the default browser and URL handler.
link "$REPO_DIR/config/mimeapps.list" "$CONFIG_DIR/mimeapps.list"

echo "== Text size =="
# One knob for shell font base-size, GTK text-scaling-factor and the terminal
# font (see omarchy-display-text-size). 10 is what this laptop runs.
omarchy display text size 10 || true

echo "== Scripts =="
mkdir -p "$HOME/.local/bin"
link "$REPO_DIR/bin/omarchy-lock-light" "$HOME/.local/bin/omarchy-lock-light"
link "$REPO_DIR/bin/omarchy-idle-audio-guard" "$HOME/.local/bin/omarchy-idle-audio-guard"
link "$REPO_DIR/bin/claude-notify" "$HOME/.local/bin/claude-notify"
link "$REPO_DIR/bin/window-close-guard" "$HOME/.local/bin/window-close-guard"
# Run from ~/Projects: every repo's uncommitted/unpushed state at a glance.
link "$REPO_DIR/bin/git-status-all" "$HOME/.local/bin/git-status-all"

echo "== Bash =="
# Omarchy's bashrc plus the herdr opaque-background wrapper. Machine-specific
# ssh aliases are deliberately NOT in here (public repo).
link "$REPO_DIR/config/bashrc" "$HOME/.bashrc"
# Repairs links Omarchy's tools turned into plain files, and reports the rest.
# Linked a second time into the post-update hook dir, so it runs after every
# `omarchy update` - that is when the drift happens.
link "$REPO_DIR/bin/omarchy-drift-check" "$HOME/.local/bin/omarchy-drift-check"
link "$REPO_DIR/bin/omarchy-drift-check" "$CONFIG_DIR/omarchy/hooks/post-update.d/50-dotfiles-drift-check"

echo "== Claude Code =="
# Carries the Notification hook that runs claude-notify above - see
# "Claude permission toasts" in CLAUDE.md.
link "$REPO_DIR/config/claude/settings.json" "$HOME/.claude/settings.json"
# Global instructions for every project (e.g. ask instead of guessing).
# Whole directory, so a new rule file in the repo is live without relinking.
link "$REPO_DIR/config/claude/rules" "$HOME/.claude/rules"

echo "== Systemd user services =="
# Keeps the screensaver/idle lock away while audio is playing (films, series).
# See the idle section in CLAUDE.md for why Firefox cannot do this itself.
# One line on purpose: omarchy-drift-check parses these `link` calls.
link "$REPO_DIR/config/systemd/user/omarchy-idle-audio-guard.service" "$CONFIG_DIR/systemd/user/omarchy-idle-audio-guard.service"
systemctl --user daemon-reload
systemctl --user enable --now omarchy-idle-audio-guard.service

echo "== GTK/GNOME settings =="
bash "$REPO_DIR/gsettings.sh"

echo "== App cleanup =="
bash "$REPO_DIR/remove-unwanted-apps.sh"

echo "== Reload =="
# The theme has to apply: it generates the shell/foot/hyprland color files
# that everything else reads. A failure here must not be hidden.
omarchy theme set crimson-core
omarchy restart shell || true
hyprctl reload || true

echo "== Link check =="
# Same check bin/omarchy-drift-check runs after every update.
broken=0
for dst in "${LINKS[@]}"; do
  if [[ ! -L $dst ]] || [[ "$(readlink -f "$dst")" != "$REPO_DIR"/* ]]; then
    echo "NOT a link into the repo: $dst"; broken=1
  fi
done
(( broken == 0 )) && echo "All ${#LINKS[@]} links point into the repo."

cat <<'EOF'

Done. Manual steps still needed on this machine:
  1. Review config/hypr/monitors.lua - the scale value (1.25 on the
     Galaxy Book's 1920x1080 panel) may need adjusting for a different
     panel. Use `omarchy hyprland monitor scaling <N>`, not a raw file
     edit - see CLAUDE.md for why.
  2. Copy your SSH key into ~/.ssh (chmod 600 the private key, 644 the
     .pub) for git push/pull over SSH.
  3. Tailscale login: `sudo tailscale up --accept-routes`.
  4. Fingerprint: skipped on purpose (see CLAUDE.md). If the new laptop
     has different hardware, check `libfprint`'s supported-devices list
     before bothering to set it up.
  5. Boot/login screen - not done automatically, because it writes to
     /usr/share and rebuilds the initramfs. Run by hand:
         omarchy plymouth set by theme crimson-core
     That styles both the Plymouth LUKS unlock prompt and the SDDM
     greeter from crimson-core's colors.toml + unlock.png. Until then the
     stock screen stays, because remove-unwanted-apps.sh already froze the
     Plymouth/SDDM files against package updates (NoExtract).
  6. Firefox: sign in to Firefox Sync for add-ons (Bitwarden, uBlock).
EOF
