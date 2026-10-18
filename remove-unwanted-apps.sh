#!/bin/bash
# Keep the machine down to what is wanted: removes unwanted stock packages,
# webapp launchers, lazy coding-agent wrappers and stock themes. Re-runnable;
# runs after every `omarchy update` as the post-update hook
# 40-dotfiles-remove-unwanted (linked by install.sh), right before the drift
# check (50-), because updates, migrations and the Install menu can bring
# things back (LibreOffice, 2026-09-24, unnoticed for three weeks).
#
# Usage: remove-unwanted-apps.sh          remove what is present
#        remove-unwanted-apps.sh --check  list what is present; exit 1 if any
set -euo pipefail

# Anything that is really needed runs in a container instead.
unwanted=(
  # Stock Omarchy apps not used here
  aether cliamp omacut kdenlive localsend moonlight-qt obs-studio pinta xournalpp
  dua-cli gnome-disk-utility mpv mpv-mpris obsidian tensaku
  # PDF viewer: Papers (GNOME's successor, a dependency of Nautilus' sushi
  # preview since Omarchy 4.0.5) does the job; mimeapps.list points PDFs at it
  evince
  # herdr replaces tmux (config/herdr mirrors the old tmux keys); the docker
  # and git terminal UIs and the screen recorder are not used
  tmux lazydocker lazygit gpu-screen-recorder
  # CJK fonts and input method: no CJK text here (JetBrains Mono everywhere)
  noto-fonts-cjk fcitx5 fcitx5-gtk fcitx5-qt
  # 2026-09-13 audit: nothing else depends on these (pacman -Rs --print dry run:
  # 90 packages, ~1.8 GiB, nothing from Omarchy, Hyprland, the shell or the boot chain)
  libreoffice-fresh clang llvm dotnet-runtime ruby tobi-try mariadb-libs postgresql-libs
  yt-dlp tesseract tesseract-data-eng tesseract-data-osd webkit2gtk-4.1 frei0r-plugins
  qemu-user-static qemu-user-static-binfmt
  cups cups-filters cups-pk-helper system-config-printer
)
# Chromium only once Brave Origin is there, so a failed browser install never
# leaves the machine without any browser.
command -v brave-origin >/dev/null && unwanted+=(chromium chromium-widevine)

# Stock webapp launchers for services not used here (their keybinds are
# unbound in config/hypr/bindings.lua). Omarchy's omarchy-refresh-applications
# and migrations can put them back; Docker.desktop is the lazydocker launcher.
launchers=(Basecamp HEY Zoom "Google Contacts" "Google Maps" "Google Messages" "Google Photos"
  X Discord WhatsApp YouTube "Disk Usage" mpv Docker)
APPS="$HOME/.local/share/applications"

# Lazy wrappers Omarchy's installer and migrations drop into ~/.local/bin:
# they run `mise use -g <tool>` on first call, which installs the tool AND
# writes it into the linked mise config, i.e. this repo. Only Claude Code is
# wanted. Only files carrying the wrapper's marker are touched.
wrappers=(codex copilot crush cursor-agent gemini grok hermes muse omp opencode pi playwright ghui)
BIN="$HOME/.local/bin"

# Stock themes kept on disk; every other shipped theme is deleted and kept
# away by pacman's NoExtract (one `!` exception per kept theme). install.sh
# sets tokyo-night as the default.
keep_themes=(tokyo-night ethereal kanagawa vantablack)
THEMES=/usr/share/omarchy/themes
noextract="NoExtract   = usr/share/omarchy/themes/*$(printf ' !usr/share/omarchy/themes/%s/*' "${keep_themes[@]}")"

mapfile -t installed < <(pacman -Qq "${unwanted[@]}" 2>/dev/null || true)
present=()
for l in "${launchers[@]}"; do [[ -e $APPS/$l.desktop ]] && present+=("$l.desktop"); done
present_wrappers=()
for w in "${wrappers[@]}"; do
  [[ -f $BIN/$w ]] && grep -q 'mise use -g' "$BIN/$w" && present_wrappers+=("$w")
done
extra_themes=() missing_themes=()
for d in "$THEMES"/*/; do
  [[ -d $d ]] || continue
  name=$(basename "$d")
  [[ " ${keep_themes[*]} " == *" $name "* ]] || extra_themes+=("$name")
done
for t in "${keep_themes[@]}"; do [[ -d $THEMES/$t ]] || missing_themes+=("$t"); done
grep -qxF "$noextract" /etc/pacman.conf && rule_ok=1 || rule_ok=0

if [[ ${1:-} == --check ]]; then
  problems=("${installed[@]}" "${present[@]}")
  for w in "${present_wrappers[@]}"; do problems+=("wrapper:$w"); done
  for t in "${extra_themes[@]}"; do problems+=("theme:$t"); done
  for t in "${missing_themes[@]}"; do problems+=("missing-theme:$t"); done
  (( rule_ok )) || problems+=("pacman-NoExtract-rule")
  (( ${#problems[@]} == 0 )) && exit 0
  printf '%s\n' "${problems[@]}"
  exit 1
fi

if (( ${#installed[@]} > 0 )); then
  echo "Removing: ${installed[*]}"
  # omarchy-pkg-drop filters the list down to what is actually installed, then
  # `sudo pacman -Rns --noconfirm` (dependencies nothing else needs go too).
  # A refused transaction (a new dependency on one of these) must not abort
  # install.sh, so it is only reported.
  omarchy-pkg-drop "${installed[@]}" \
    || echo "WARN: package removal failed - check 'pacman -Rns --print ${installed[*]}' by hand"
fi
# fcitx5 is gone, so its user service must not fail at every login.
systemctl --user disable --now omarchy-fcitx5.service 2>/dev/null || true

for l in "${launchers[@]}"; do rm -f "$APPS/$l.desktop"; done
update-desktop-database "$APPS" 2>/dev/null || true

for w in "${present_wrappers[@]}"; do
  rm -f "$BIN/$w"
  command -v mise >/dev/null && mise uninstall --all "$w" >/dev/null 2>&1
done

# Stock themes: there is no supported way to *hide* one - omarchy-theme-list
# globs $THEMES unconditionally - so the unwanted ones are deleted, and
# pacman's NoExtract keeps `omarchy update` from putting them back. Undo by
# deleting the NoExtract line and running `sudo pacman -S omarchy`.
# Never put NoExtract on the Plymouth/SDDM theme dirs: pacman still removes
# the old files on upgrade, which left a bare-text LUKS prompt (2026-09-16).
if (( ! rule_ok )); then
  sudo cp -a /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%s)"
  # Replace an older form of the rule, or add it under [options].
  if grep -q '^NoExtract *= *usr/share/omarchy/themes' /etc/pacman.conf; then
    sudo sed -i "s|^NoExtract *= *usr/share/omarchy/themes.*|$noextract|" /etc/pacman.conf
  else
    sudo sed -i "/^\[options\]/a # Stock Omarchy themes not kept here are deleted; keep updates from restoring them.\n$noextract" /etc/pacman.conf
  fi
fi
# Only ask for sudo when there is something to delete.
if (( ${#extra_themes[@]} > 0 )); then
  sudo rm -rf -- "${extra_themes[@]/#/$THEMES/}" || echo "WARN: could not delete the stock themes"
fi
if (( ${#missing_themes[@]} > 0 )); then
  echo "WARN: kept themes missing (${missing_themes[*]}) - run: sudo pacman -S omarchy"
fi

echo "Done. Run 'pacman -Qtdq' afterwards to check for newly-orphaned deps."
