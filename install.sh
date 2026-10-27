#!/bin/bash
# Bring a fresh Omarchy install up to the same config as this repo.
# Usage: run it from wherever the repo is checked out, e.g.
#   ~/Projects/paulgradischnig/dotfiles/install.sh
# REPO_DIR is derived from this file's own location, so the clone path is
# free - but the symlinks it creates bake it in. Moving the repo afterwards
# leaves them dangling; re-run this script then. Re-running is safe.
set -euo pipefail
(( EUID == 0 )) && { echo "Run as your user, not root; sudo is called where needed." >&2; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
STAMP="$(date +%s)"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

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
# upgrading, which is the partial-upgrade trap on Arch; run `omarchy update`
# first on an installation that is more than a few days old.
mapfile -t PACMAN_PKGS < <(sed -n '/^\[aur\]/q; s/\s*#.*//; s/\s+$//; /^\s*$/d; p' "$REPO_DIR/packages.txt")
mapfile -t AUR_PKGS < <(sed -n '/^\[aur\]/,$ { /^\[aur\]/d; s/\s*#.*//; s/\s+$//; /^\s*$/d; p }' "$REPO_DIR/packages.txt")
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
# policy. It `cp -f`s its flags file, which would write through an existing
# link into the repo - so the link goes first (re-run after a failed install).
# Privacy defaults go in as a second policy file next to Omarchy's color.json
# (the only file Omarchy rewrites there). The default browser itself comes
# from the linked mimeapps.list below.
if ! command -v brave-origin >/dev/null; then
  [[ -L $CONFIG_DIR/brave-origin-flags.conf ]] && rm "$CONFIG_DIR/brave-origin-flags.conf"
  omarchy install browser brave-origin || echo "WARN: 'omarchy install browser brave-origin' failed - no browser until it is installed"
fi
sudo install -Dm644 "$REPO_DIR/config/brave/privacy.json" /etc/brave/policies/managed/privacy.json
# Battery stops charging at 80% (see the unit's header); only where the
# samsung_galaxybook driver offers the threshold, the unit skips itself elsewhere.
sudo install -Dm644 "$REPO_DIR/config/systemd/battery-charge-limit.service" /etc/systemd/system/battery-charge-limit.service
sudo systemctl daemon-reload && sudo systemctl enable --now battery-charge-limit.service
# ClamAV signatures once a day (and right now). No clamd daemon: scans run on
# demand only (CHEATSHEET, "Sicherheit"); a resident clamd holds 1.6 GB+ RAM.
sudo systemctl enable --now clamav-freshclam-once.timer
sudo systemctl start clamav-freshclam-once.service || echo "WARN: ClamAV signatures not downloaded - run: sudo freshclam"
# Omarchy's launch flags (Wayland, libsecret) minus its --load-extension line:
# the Copy-URL, yt-dlp and WhatsApp-slim extensions are not wanted.
link "$REPO_DIR/config/brave/brave-origin-flags.conf" "$CONFIG_DIR/brave-origin-flags.conf"

echo "== Tailscale =="
# The service and the operator right only (the operator lets the bar widget
# in shell.json connect and switch without sudo); `sudo tailscale up` (the
# login) is interactive and stays a manual step.
sudo systemctl enable --now tailscaled.service
sudo tailscale set --operator="$USER" || echo "WARN: tailscale operator not set - run: sudo tailscale set --operator=$USER"

echo "== Hyprland config =="
for f in "$REPO_DIR"/config/hypr/*.lua; do
  link "$f" "$CONFIG_DIR/hypr/$(basename "$f")"
done
# Touchscreen off: a touch event while the locked panel was waking up crashed
# Hyprland 0.56.2 (incidents repo, 2026-10-27). Omarchy's own toggle keeps the
# device name in ~/.local/state and re-applies it on every reload; it needs a
# running Hyprland to find the device. Back on: omarchy toggle touchscreen on
if ! hyprctl -j devices >/dev/null 2>&1; then
  echo "WARN: Hyprland not running - touchscreen not checked; run: omarchy toggle touchscreen off"
elif [[ -n $(omarchy-hw-touchscreen) ]]; then
  omarchy toggle touchscreen off
fi

echo "== Omarchy shell =="
link "$REPO_DIR/config/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json"
# Machine-level shell values that win over every theme: font base-size 12
# (Omarchy's stock size) and a thinner bar.
link "$REPO_DIR/config/omarchy/shell.toml" "$CONFIG_DIR/omarchy/shell.toml"
# SUPER+W's "close anyway?" dialog, summoned by bin/window-close-guard.
link "$REPO_DIR/config/omarchy/plugins/gradiscp.closeconfirm" "$CONFIG_DIR/omarchy/plugins/gradiscp.closeconfirm"
# Clone of omarchy.workspaces (dot workspaces) and the Claude waiting-count
# widget. shell.json above already points the bar at these ids.
link "$REPO_DIR/config/omarchy/plugins/gradiscp.workspaces" "$CONFIG_DIR/omarchy/plugins/gradiscp.workspaces"
link "$REPO_DIR/config/omarchy/plugins/gradiscp.claude-status" "$CONFIG_DIR/omarchy/plugins/gradiscp.claude-status"
# An own background for the stock Kanagawa theme. User backgrounds sort before
# the theme's own, so it is the first one when Kanagawa is set. Directory
# link: `omarchy theme bg install` adds files here, i.e. into the repo.
link "$REPO_DIR/config/omarchy/backgrounds/kanagawa" "$CONFIG_DIR/omarchy/backgrounds/kanagawa"
# Menu override: hides the Share submenu (every entry needs localsend).
link "$REPO_DIR/config/omarchy/extensions/omarchy-menu.jsonc" "$CONFIG_DIR/omarchy/extensions/omarchy-menu.jsonc"
# Default coding agent for Omarchy's menu and SUPER+CTRL+SHIFT+A. Written
# directly: `omarchy default agent` would run `mise use -g` through the linked
# mise config and launch the agent.
mkdir -p "$CONFIG_DIR/omarchy/defaults" && printf 'claude\n' >"$CONFIG_DIR/omarchy/defaults/agent"

echo "== Cursor (Bibata-Modern-Ice, single variant) =="
# 1.7 MB download (27 MB unpacked) from the upstream release instead of the
# 322 MB AUR package that bundles every variant. Pinned version and checksum;
# the archive holds only cursors/, index.theme and cursor.theme (checked
# 2026-10-15). Unpacked in a temp dir and moved into place in one step, so an
# interrupted run cannot leave a half theme that the check below would accept.
CURSOR_DIR="$HOME/.local/share/icons/Bibata-Modern-Ice"
CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz"
CURSOR_SHA256="a68cae60c4dc706350e194ebc91c5fe48bc7bc9d59e119555834a2a7ee5078ef"
if [[ ! -d $CURSOR_DIR/cursors || ! -f $CURSOR_DIR/index.theme ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if curl -fsSL -o "$tmp/cursor.tar.xz" "$CURSOR_URL" \
    && echo "$CURSOR_SHA256  $tmp/cursor.tar.xz" | sha256sum -c --quiet \
    && tar -xJf "$tmp/cursor.tar.xz" -C "$tmp" \
    && mkdir -p "$(dirname "$CURSOR_DIR")" \
    && rm -rf "$CURSOR_DIR" && mv "$tmp/Bibata-Modern-Ice" "$CURSOR_DIR"; then
    echo "Installed $CURSOR_DIR"
  else
    echo "WARN: cursor theme download or checksum failed - stock cursor stays"
  fi
  rm -rf "$tmp"; trap - EXIT
fi

echo "== Claude sounds (herdr's request/done, played by claude-notify) =="
# herdr's own two sounds (Apache-2.0), pinned to the v0.9.1 tag - the files
# are byte-identical to the ones built into that herdr. herdr is silenced for
# Claude in config/herdr/config.toml; claude-notify plays these instead, so
# the bar panel can switch them off without touching that linked file.
SOUND_DIR="$HOME/.local/share/claude-notify/sounds"
SOUND_URL="https://raw.githubusercontent.com/herdrdev/herdr/v0.9.1/assets/sounds"
declare -A SOUND_SHA256=(
  [request]="44c077ce28a0a48cec29da204beb627fd17140e5bde1f92dbaecf3d478bdda6f"
  [done]="cb9c93492c808e33946edac2ab5915758267e65914bc4b794a5ca6dc6e655741"
)
mkdir -p "$SOUND_DIR"
for sound in request done; do
  [[ -f $SOUND_DIR/$sound.mp3 ]] && continue
  tmp="$(mktemp)"
  if curl -fsSL -o "$tmp" "$SOUND_URL/$sound.mp3" \
    && echo "${SOUND_SHA256[$sound]}  $tmp" | sha256sum -c --quiet; then
    mv "$tmp" "$SOUND_DIR/$sound.mp3" && echo "Installed $SOUND_DIR/$sound.mp3"
  else
    rm -f "$tmp"
    echo "WARN: $sound sound download or checksum failed - no Claude $sound sound"
  fi
done

echo "== Fontconfig (JetBrains Mono everywhere) =="
link "$REPO_DIR/config/fontconfig/conf.d/51-jetbrains.conf" "$CONFIG_DIR/fontconfig/conf.d/51-jetbrains.conf"
fc-cache -f >/dev/null 2>&1 || echo "WARN: fc-cache failed"

echo "== Neovim =="
# One plugin on top of Omarchy's LazyVim: Markdown rendered in the buffer.
# lazy.nvim fetches it on the first start.
link "$REPO_DIR/config/nvim/lua/plugins/markdown.lua" "$CONFIG_DIR/nvim/lua/plugins/markdown.lua"

echo "== Code - OSS =="
# Settings linked: theme Matte Black with Material icons, a quiet UI, no window
# buttons (window.controlsStyle, needs a full restart). Theme extensions come
# from Open VSX, Code - OSS's gallery. Omarchy's theme sync is off for `code`:
# it writes Microsoft VS Code's ~/.config/Code (never read by Code - OSS) but
# installs each Omarchy theme's extension into Code - OSS.
link "$REPO_DIR/config/code-oss/settings.json" "$CONFIG_DIR/Code - OSS/User/settings.json"
for ext in tahayvr.matteblack pkief.material-icon-theme pkief.material-product-icons; do
  code --install-extension "$ext" >/dev/null || echo "WARN: Code extension $ext not installed - run: code --install-extension $ext"
done
omarchy toggle skip-vscode-theme-changes on

echo "== Environment =="
# Omarchy's /usr/lib/environment.d/10-omarchy-fcitx.conf points Qt, SDL and
# XWayland at the fcitx5 input method, which remove-unwanted-apps.sh removes.
# A user file of the same name masks it (empty on purpose). Takes effect at
# the next login.
link "$REPO_DIR/config/environment.d/10-omarchy-fcitx.conf" "$CONFIG_DIR/environment.d/10-omarchy-fcitx.conf"

echo "== herdr, git, mise, default apps =="
link "$REPO_DIR/config/herdr/config.toml" "$CONFIG_DIR/herdr/config.toml"
link "$REPO_DIR/config/git/config" "$CONFIG_DIR/git/config"
link "$REPO_DIR/config/git/ignore" "$CONFIG_DIR/git/ignore"
# Tool versions for claude and gh (plus upgrade.auto_prune = false, which
# Omarchy sets for a reason: `mise up` must not prune the Claude binary that
# running sessions started from). The other coding agents Omarchy drops in as
# lazy wrappers are removed by remove-unwanted-apps.sh (App cleanup below).
# node is not installed at all (claude is a native binary, pnpm 12 is
# standalone).
link "$REPO_DIR/config/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
if command -v mise >/dev/null; then
  mise install || echo "WARN: mise install failed - run 'mise install' by hand"
  mise uninstall --all node >/dev/null 2>&1 || true
fi
# Brave Origin as the default browser and URL handler. Omarchy's "default
# browser" menu writes this file (through the link on 2026-10-15, so the
# change landed in the repo; if it replaces the link, the drift check
# re-links). The claude-cli:// line points at claude-code-url-handler.desktop,
# which Claude Code writes itself on first run.
link "$REPO_DIR/config/mimeapps.list" "$CONFIG_DIR/mimeapps.list"

echo "== Scripts =="
mkdir -p "$HOME/.local/bin"
link "$REPO_DIR/bin/claude-notify" "$HOME/.local/bin/claude-notify"
link "$REPO_DIR/bin/window-close-guard" "$HOME/.local/bin/window-close-guard"
# Run from ~/Projects: git-all [status|fetch|pull|push] over every repo below.
link "$REPO_DIR/bin/git-all" "$HOME/.local/bin/git-all"
# Repairs links Omarchy's tools turned into plain files, and reports the rest
# (returned packages and launchers, the Brave policy copy). Linked a second
# time into the post-update hook dir, so it runs after every `omarchy update`.
link "$REPO_DIR/bin/omarchy-drift-check" "$HOME/.local/bin/omarchy-drift-check"
link "$REPO_DIR/bin/omarchy-drift-check" "$CONFIG_DIR/omarchy/hooks/post-update.d/50-dotfiles-drift-check"
# Runs before the drift check (hooks run in name order): takes out whatever an
# update or a migration brought back, so the check after it sees the result.
link "$REPO_DIR/remove-unwanted-apps.sh" "$CONFIG_DIR/omarchy/hooks/post-update.d/40-dotfiles-remove-unwanted"

echo "== Claude Code =="
# herdr's Claude hook: reports each session's id so herdr can `claude --resume`
# it after a reboot. It writes ~/.claude/hooks/herdr-agent-state.sh AND a
# SessionStart entry with an absolute home path into ~/.claude/settings.json -
# so it runs only BEFORE settings.json is linked (the repo copy already
# carries the same hook with $HOME) and only when its script is missing.
# Through the link it would write that absolute path into the public repo
# (happened 2026-10-15). To upgrade the hook later: run it, then
# `git checkout -- config/claude/settings.json`.
if command -v herdr >/dev/null && [[ ! -f $HOME/.claude/hooks/herdr-agent-state.sh && ! -L $HOME/.claude/settings.json ]]; then
  herdr integration install claude || echo "WARN: 'herdr integration install claude' failed"
fi
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

echo "== GTK/GNOME settings =="
# What Omarchy's own configs don't cover. gsettings set is idempotent and
# needs a session bus (fails harmlessly on a bare TTY).
# text-scaling-factor is deliberately NOT set: `omarchy display text size`
# above drives it together with the shell and terminal font size.
{
  gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 11' &&
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11' &&
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' &&
  gsettings set org.gnome.desktop.interface cursor-size 14 &&
  gsettings set org.gnome.desktop.wm.preferences button-layout ''
} || echo "WARN: gsettings failed (no session bus?) - re-run inside the desktop"

echo "== App cleanup =="
bash "$REPO_DIR/remove-unwanted-apps.sh" || echo "WARN: app cleanup reported a problem (see above)"

echo "== Theme and reload =="
# Tokyo Night is the default of the stock themes kept on disk (the list is in
# remove-unwanted-apps.sh); it generates the shell/foot/hyprland colour files
# that everything else reads, so a failure here must not be hidden.
omarchy theme set tokyo-night || echo "WARN: 'omarchy theme set tokyo-night' failed - run 'omarchy theme list' and set it by hand"
omarchy restart shell || echo "WARN: 'omarchy restart shell' failed"
hyprctl reload || echo "WARN: 'hyprctl reload' failed (not inside a Hyprland session?)"

echo "== Link check =="
# Re-links any copy Omarchy's tools left behind above, reports the rest.
"$HOME/.local/bin/omarchy-drift-check" --quiet || echo "WARN: drift check found problems (see above)"

cat <<'EOT'

Done. Manual steps still needed on this machine:
  1. Log out and in again: cursor and environment variables reach apps only
     from a fresh session.
  2. Review config/hypr/monitors.lua - the laptop scale (1 on a 1920x1080
     panel) may need adjusting for a different panel. Use
     `omarchy hyprland monitor scaling <N>`, not a raw file edit - see
     CLAUDE.md for why. The external monitors keep their own literal scale.
  3. SSH: copy the key into ~/.ssh (chmod 600 / 644), add the host alias to
     ~/.ssh/config, then `git remote set-url origin` to it (CHEATSHEET).
  4. Logins: `sudo tailscale up --accept-routes`, `gh auth login`, `claude`.
  5. Brave Origin: the hand-set items in CHEATSHEET.md (uBlock Origin from
     config/brave/ublock-origin-backup.txt, Bitwarden, Shields, zoom, DNS).
  6. Machine-specific, untracked files: ~/.config/git/config.local (extra
     git identities and their include files) and
     config/claude/rules/*.local.md (private rules).
  7. Fingerprint: skipped on purpose; check libfprint's device list first.
EOT
