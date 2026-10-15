#!/bin/bash
# Bring a fresh Omarchy install up to the same config as this repo.
# Usage: run it from wherever the repo is checked out, e.g.
#   ~/Projects/paulgradischnig/dotfiles/install.sh
# REPO_DIR is derived from this file's own location, so the clone path is
# free - but the symlinks it creates bake it in. Moving the repo afterwards
# leaves them dangling; re-run this script then.
set -euo pipefail
(( EUID == 0 )) && { echo "Run as your user, not root; sudo is called where needed." >&2; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
STAMP="$(date +%s)"

# Every `link` call stays on one line: omarchy-drift-check parses them (plus
# the config/hypr/*.lua loop) as the one list of what must point into the repo.
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
# packages.txt: one name per line, "#" comments, an [aur] header switches to
# the AUR list. -S without -y: a plain -Sy refreshes the database without
# upgrading, which is the partial-upgrade trap on Arch; keep updating to
# `omarchy update`.
mapfile -t PACMAN_PKGS < <(sed -n '/^\[aur\]/q; s/#.*//; /^\s*$/d; p' "$REPO_DIR/packages.txt")
mapfile -t AUR_PKGS < <(sed -n '/^\[aur\]/,$ { /^\[aur\]/d; s/#.*//; /^\s*$/d; p }' "$REPO_DIR/packages.txt")
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
if (( ${#AUR_PKGS[@]} > 0 )); then
  if command -v yay >/dev/null; then
    # No --noconfirm here: AUR packages are user-submitted build scripts, so
    # yay should get the chance to show each PKGBUILD before it builds.
    yay -S --needed "${AUR_PKGS[@]}"
  else
    echo "WARN: yay not found, skipping AUR packages (${AUR_PKGS[*]}) - install yay first."
  fi
fi

echo "== Browser (Brave Origin) =="
# Omarchy's own installer: AUR package brave-origin-bin, Wayland flags, theme
# policy. Privacy defaults go in as a second policy file next to Omarchy's
# color.json (that is the only file Omarchy rewrites there). The default
# browser itself comes from the linked mimeapps.list below.
command -v brave-origin >/dev/null || omarchy install browser brave-origin || echo "WARN: 'omarchy install browser brave-origin' failed"
sudo install -Dm644 "$REPO_DIR/config/brave/privacy.json" /etc/brave/policies/managed/privacy.json
# Omarchy's launch flags (Wayland, libsecret) minus its --load-extension line:
# the Copy-URL, yt-dlp and WhatsApp-slim extensions are not wanted. Linked
# after the installer, which would otherwise cp its stock copy over it.
link "$REPO_DIR/config/brave/brave-origin-flags.conf" "$CONFIG_DIR/brave-origin-flags.conf"

echo "== Tailscale =="
# The service and the operator right only; `sudo tailscale up` (the login) is
# interactive and stays a manual step. Omarchy's own installer also adds a
# Chromium webapp and a bar widget, neither wanted here.
sudo systemctl enable --now tailscaled.service
sudo tailscale set --operator="$USER" || echo "WARN: tailscale operator not set - run: sudo tailscale set --operator=$USER"

echo "== Hyprland config =="
for f in "$REPO_DIR"/config/hypr/*.lua; do
  link "$f" "$CONFIG_DIR/hypr/$(basename "$f")"
done

echo "== Omarchy shell =="
link "$REPO_DIR/config/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json"
# SUPER+W's "close anyway?" dialog, summoned by bin/window-close-guard.
link "$REPO_DIR/config/omarchy/plugins/gradiscp.closeconfirm" "$CONFIG_DIR/omarchy/plugins/gradiscp.closeconfirm"
# Clone of omarchy.workspaces (dot workspaces) and the Claude waiting-count
# widget. shell.json above already points the bar at these ids.
link "$REPO_DIR/config/omarchy/plugins/gradiscp.workspaces" "$CONFIG_DIR/omarchy/plugins/gradiscp.workspaces"
link "$REPO_DIR/config/omarchy/plugins/gradiscp.claude-status" "$CONFIG_DIR/omarchy/plugins/gradiscp.claude-status"
# Own themes (whole directories: each is its own theme, not an overlay).
# omarchy-theme-list globs both dirs and symlinks, so linking is enough. They
# stay selectable next to Tokyo Night, which install.sh sets below.
link "$REPO_DIR/config/omarchy/themes/crimson-core" "$CONFIG_DIR/omarchy/themes/crimson-core"
link "$REPO_DIR/config/omarchy/themes/apple-coast" "$CONFIG_DIR/omarchy/themes/apple-coast"
# Menu override: hides the Share submenu (every entry needs localsend).
link "$REPO_DIR/config/omarchy/extensions/omarchy-menu.jsonc" "$CONFIG_DIR/omarchy/extensions/omarchy-menu.jsonc"

echo "== Text size =="
# One knob for shell font base-size, GTK text-scaling-factor and the terminal
# font (see omarchy-display-text-size). 10 is what this laptop runs.
omarchy display text size 10 || echo "WARN: 'omarchy display text size 10' failed - run it by hand"

echo "== Cursor (Bibata-Modern-Ice, single variant) =="
# 1.7 MB from the upstream release instead of the 322 MB AUR package that
# bundles every variant. Pinned version and checksum; the archive holds only
# cursors/, index.theme and cursor.theme (checked 2026-10-15).
CURSOR_DIR="$HOME/.local/share/icons/Bibata-Modern-Ice"
CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz"
CURSOR_SHA256="a68cae60c4dc706350e194ebc91c5fe48bc7bc9d59e119555834a2a7ee5078ef"
if [[ ! -f $CURSOR_DIR/index.theme ]]; then
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/cursor.tar.xz" "$CURSOR_URL" \
    && echo "$CURSOR_SHA256  $tmp/cursor.tar.xz" | sha256sum -c --quiet \
    && mkdir -p "$(dirname "$CURSOR_DIR")" \
    && tar -xJf "$tmp/cursor.tar.xz" -C "$(dirname "$CURSOR_DIR")"; then
    echo "Installed $CURSOR_DIR"
  else
    echo "WARN: cursor theme download or checksum failed - stock cursor stays"
  fi
  rm -rf "$tmp"
fi

echo "== Fontconfig (JetBrains Mono everywhere) =="
link "$REPO_DIR/config/fontconfig/conf.d/51-jetbrains.conf" "$CONFIG_DIR/fontconfig/conf.d/51-jetbrains.conf"
fc-cache -f >/dev/null 2>&1 || echo "WARN: fc-cache failed"

echo "== herdr, git, mise, default apps =="
link "$REPO_DIR/config/herdr/config.toml" "$CONFIG_DIR/herdr/config.toml"
link "$REPO_DIR/config/git/config" "$CONFIG_DIR/git/config"
link "$REPO_DIR/config/git/ignore" "$CONFIG_DIR/git/ignore"
# Tool versions for claude and gh; `mise install` fetches them. Omarchy's own
# installer and migrations (omarchy-mise-install) also drop lazy wrappers for
# other coding agents into ~/.local/bin that install the agent on first run;
# only Claude Code is wanted here, so those go again, installed or not.
link "$REPO_DIR/config/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
if command -v mise >/dev/null; then
  mise install || echo "WARN: mise install failed - run 'mise install' by hand"
  for tool in codex copilot crush cursor-agent gemini grok hermes muse omp opencode pi; do
    mise uninstall --all "$tool" >/dev/null 2>&1 || true
    rm -f "$HOME/.local/bin/$tool"
  done
  echo "mise tools now: $(mise ls 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ')"
fi
# Brave Origin as the default browser and URL handler (xdg-settings writes
# through this link, so a change via Omarchy's menu lands in the repo). The
# claude-cli:// line points at claude-code-url-handler.desktop, which Claude
# Code writes itself on first run (absolute path, so it is not in the repo).
link "$REPO_DIR/config/mimeapps.list" "$CONFIG_DIR/mimeapps.list"
# The lazydocker launcher (SUPER+SHIFT+D's menu entry) stays the stock
# Omarchy copy: Omarchy migrations `cp` over this path, so it must be a plain
# file, not a link into the repo. Only put it back if it is missing.
DOCKER_DESKTOP="$HOME/.local/share/applications/Docker.desktop"
if [[ ! -f $DOCKER_DESKTOP || -L $DOCKER_DESKTOP ]]; then
  mkdir -p "$(dirname "$DOCKER_DESKTOP")"
  cp --remove-destination "${OMARCHY_PATH:-/usr/share/omarchy}/applications/Docker.desktop" "$DOCKER_DESKTOP"
fi

echo "== Scripts =="
mkdir -p "$HOME/.local/bin"
link "$REPO_DIR/bin/claude-notify" "$HOME/.local/bin/claude-notify"
link "$REPO_DIR/bin/window-close-guard" "$HOME/.local/bin/window-close-guard"
# Run from ~/Projects: git-all [status|fetch|pull|push] over every repo below.
link "$REPO_DIR/bin/git-all" "$HOME/.local/bin/git-all"
# Repairs links Omarchy's tools turned into plain files, and reports the rest
# (including stock packages an update reinstalled). Linked a second time into
# the post-update hook dir, so it runs after every `omarchy update` - that is
# when the drift happens.
link "$REPO_DIR/bin/omarchy-drift-check" "$HOME/.local/bin/omarchy-drift-check"
link "$REPO_DIR/bin/omarchy-drift-check" "$CONFIG_DIR/omarchy/hooks/post-update.d/50-dotfiles-drift-check"

echo "== Claude Code =="
# Carries the hooks that run claude-notify above - see the header of
# bin/claude-notify. Claude Code rewrites this file through the link
# (/model, /config, "always allow"): diff it before committing.
link "$REPO_DIR/config/claude/settings.json" "$HOME/.claude/settings.json"
# Global instructions for every project (e.g. ask instead of guessing).
# Whole directory, so a new rule file in the repo is live without relinking;
# machine-specific rules go in *.local.md there (gitignored, still loaded).
link "$REPO_DIR/config/claude/rules" "$HOME/.claude/rules"
# Own skills, one directory each (the Omarchy ones are linked by Omarchy itself).
link "$REPO_DIR/config/claude/skills/docu-guard" "$HOME/.claude/skills/docu-guard"
# herdr's Claude hook: reports each session's id so herdr can `claude --resume`
# it after a reboot. Writes ~/.claude/hooks/herdr-agent-state.sh and the
# SessionStart entry in settings.json (through the link above).
if command -v herdr >/dev/null; then
  herdr integration install claude || echo "WARN: 'herdr integration install claude' failed"
fi

echo "== GTK/GNOME settings =="
# What Omarchy's own configs don't cover. gsettings set is idempotent.
# text-scaling-factor is deliberately NOT set: `omarchy display text size`
# above drives it together with the shell and terminal font size.
gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 14
gsettings set org.gnome.desktop.wm.preferences button-layout ''

echo "== App cleanup =="
bash "$REPO_DIR/remove-unwanted-apps.sh" || echo "WARN: app cleanup reported a problem (see above)"

echo "== Theme and reload =="
# Tokyo Night is the stock theme kept on disk (remove-unwanted-apps.sh deletes
# the other stock ones); it generates the shell/foot/hyprland colour files
# that everything else reads, so a failure here must not be hidden.
omarchy theme set tokyo-night || echo "WARN: 'omarchy theme set tokyo-night' failed - run 'omarchy theme list' and set it by hand"
omarchy restart shell || echo "WARN: 'omarchy restart shell' failed"
hyprctl reload || echo "WARN: 'hyprctl reload' failed (not inside a Hyprland session?)"

echo "== Link check =="
# Re-links any copy Omarchy's tools left behind above, reports the rest.
"$HOME/.local/bin/omarchy-drift-check" --quiet || echo "WARN: drift check found problems (see above)"

cat <<'EOT'

Done. Manual steps still needed on this machine:
  1. Review config/hypr/monitors.lua - the laptop scale (1 on a 1920x1080
     panel) may need adjusting for a different panel. Use
     `omarchy hyprland monitor scaling <N>`, not a raw file edit - see
     CLAUDE.md for why. The external monitors keep their own literal scale.
  2. Copy your SSH key into ~/.ssh (chmod 600 the private key, 644 the
     .pub) for git push/pull over SSH.
  3. Tailscale login: `sudo tailscale up --accept-routes`.
  4. Fingerprint: skipped on purpose. Check libfprint's supported-devices
     list for this laptop's sensor before bothering to set it up.
  5. Brave Origin: enable uBlock Origin under brave://settings/extensions/v2
     and restore config/brave/ublock-origin-backup.txt in its dashboard;
     install Bitwarden; set Shields to Aggressive (see CHEATSHEET).
  6. Machine-specific, untracked files: ~/.config/git/config.local (extra
     git identities) and config/claude/rules/*.local.md (private rules).
EOT
