#!/bin/bash
# Strip packages from the stock Omarchy set that aren't wanted here, and keep
# the stock themes down to Tokyo Night. Re-runnable: a listed package can
# come back through any `pacman -S` or Omarchy's Install menu (LibreOffice,
# 2026-09-24, unnoticed for three weeks), which omarchy-drift-check reports
# via `--check`.
#
# Usage: remove-unwanted-apps.sh          remove what is installed
#        remove-unwanted-apps.sh --check  list unwanted packages and launchers
#                                         that are present; exit 1 if any
set -euo pipefail

# Anything that is really needed runs in a container instead.
unwanted=(
  # Stock Omarchy apps not used here
  aether cliamp omacut kdenlive localsend moonlight-qt obs-studio pinta xournalpp
  dua-cli gnome-disk-utility mpv mpv-mpris obsidian tensaku
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
# can put them back. Docker.desktop stays: it launches lazydocker in a terminal.
launchers=(Basecamp HEY Zoom "Google Contacts" "Google Maps" "Google Messages" "Google Photos"
  X Discord WhatsApp YouTube "Disk Usage" mpv)
APPS="$HOME/.local/share/applications"

mapfile -t installed < <(pacman -Qq "${unwanted[@]}" 2>/dev/null || true)
present=()
for l in "${launchers[@]}"; do [[ -e $APPS/$l.desktop ]] && present+=("$l.desktop"); done
if [[ ${1:-} == --check ]]; then
  (( ${#installed[@]} + ${#present[@]} == 0 )) && exit 0
  printf '%s\n' "${installed[@]}" "${present[@]}"
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

# Stock themes: only Tokyo Night is used (plus the two themes in this repo),
# so the other 21 shipped ones (~115MB) go. There is no supported way to
# *hide* a theme - omarchy-theme-list globs $OMARCHY_PATH/themes
# unconditionally - so they are deleted, and pacman's NoExtract (with a `!`
# exception for tokyo-night) keeps `omarchy update` from putting them back.
# Undo both by deleting the NoExtract line and running `sudo pacman -S omarchy`.
# Never put NoExtract on the Plymouth/SDDM theme dirs: pacman still removes
# the old files on upgrade, which left a bare-text LUKS prompt (2026-09-16).
noextract='NoExtract   = usr/share/omarchy/themes/* !usr/share/omarchy/themes/tokyo-night/*'
if ! grep -qxF "$noextract" /etc/pacman.conf; then
  sudo cp -a /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%s)"
  # Replace an older form of the rule, or add it under [options].
  if grep -q '^NoExtract *= *usr/share/omarchy/themes' /etc/pacman.conf; then
    sudo sed -i "s|^NoExtract *= *usr/share/omarchy/themes.*|$noextract|" /etc/pacman.conf
  else
    sudo sed -i "/^\[options\]/a # Stock Omarchy themes except Tokyo Night are deleted here; keep updates from restoring them.\n$noextract" /etc/pacman.conf
  fi
fi
# Only ask for sudo when there is something to delete.
if [[ -n $(find /usr/share/omarchy/themes -mindepth 1 -maxdepth 1 -type d ! -name tokyo-night 2>/dev/null | head -1) ]]; then
  sudo find /usr/share/omarchy/themes -mindepth 1 -maxdepth 1 -type d ! -name tokyo-night -exec rm -rf {} + \
    || echo "WARN: could not delete the stock themes"
fi

echo "Done. Run 'pacman -Qtdq' afterwards to check for newly-orphaned deps."
