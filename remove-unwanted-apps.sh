#!/bin/bash
# Strip apps from the stock Omarchy set that aren't wanted here.
set -euo pipefail

# Anything that is really needed runs in a container instead (see CLAUDE.md).
unwanted=(
  # Stock Omarchy apps not used here
  aether cliamp omacut kdenlive localsend moonlight-qt obs-studio pinta xournalpp
  # Firefox is the browser; chromium-widevine only installs into /usr/lib/chromium
  chromium chromium-widevine
  # 2026-09-13 audit: nothing else depends on these (pacman -Rs --print dry run:
  # 90 packages, ~1.8 GiB, nothing from Omarchy, Hyprland, the shell or the boot chain)
  libreoffice-fresh clang llvm dotnet-runtime ruby tobi-try mariadb-libs postgresql-libs
  yt-dlp tesseract tesseract-data-eng tesseract-data-osd webkit2gtk-4.1 frei0r-plugins
  qemu-user-static qemu-user-static-binfmt
  cups cups-filters cups-pk-helper system-config-printer
)
# omarchy-pkg-drop filters the list down to what is actually installed, then
# `sudo pacman -Rns --noconfirm` (dependencies nothing else needs go too).
# The filter matters: pacman aborts the whole transaction if one name is
# missing, which is why an earlier fixed list removed nothing on re-runs.
omarchy-pkg-drop "${unwanted[@]}"

rm -f ~/.local/share/applications/Basecamp.desktop \
      ~/.local/share/applications/HEY.desktop \
      ~/.local/share/applications/Zoom.desktop \
      ~/.local/share/applications/"Google Contacts.desktop" \
      ~/.local/share/applications/"Google Maps.desktop" \
      ~/.local/share/applications/"Google Messages.desktop" \
      ~/.local/share/applications/"Google Photos.desktop" \
      ~/.local/share/applications/X.desktop \
      ~/.local/share/applications/Discord.desktop \
      ~/.local/share/applications/WhatsApp.desktop \
      ~/.local/share/applications/YouTube.desktop

# NOT Docker.desktop - that one launches lazydocker in a terminal, doesn't
# go through omarchy-launch-webapp, so it never needed Chromium at all.
# The webapp shortcuts above are removed because Chromium is uninstalled here
# (see CLAUDE.md) and omarchy-launch-webapp hardcodes a Chromium-family
# browser for every one of them - they'd just error out otherwise.

update-desktop-database ~/.local/share/applications 2>/dev/null || true

# Stock themes: only crimson-core is used here, so the 22 shipped ones (~119MB)
# go too. There is no supported way to *hide* a theme - omarchy-theme-list globs
# $OMARCHY_PATH/themes unconditionally - so they have to be deleted, and pacman's
# NoExtract is what keeps `omarchy update` from putting them back. Undo both by
# deleting the NoExtract line and running `sudo pacman -S omarchy`.
if ! grep -qF 'usr/share/omarchy/themes/*' /etc/pacman.conf; then
  sudo cp -a /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%s)"
  sudo sed -i '/^\[options\]/a\\n# Stock Omarchy themes are deleted here; keep updates from restoring them.\nNoExtract   = usr/share/omarchy/themes/*' /etc/pacman.conf
fi
sudo find /usr/share/omarchy/themes -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true

# Boot/login screen: NOT protected with NoExtract. That was tried on
# 2026-09-13 and emptied both theme directories on the next omarchy-settings
# upgrade (4.0.4, 2026-09-16): pacman skips extracting NoExtract'd files, but
# still removes the old package's copies, so the LUKS prompt fell back to
# text mode and SDDM showed a black screen after logout. The boot screen is
# stock Omarchy now (the crimson-core restyle was dropped 2026-09-21); this
# block only removes the old rule if it is still present.
if grep -qF 'usr/share/plymouth/themes/omarchy/*' /etc/pacman.conf; then
  sudo cp -a /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%s)"
  sudo sed -i '/keep updates from resetting it/d; /^NoExtract *= *usr\/share\/plymouth\/themes\/omarchy/d' /etc/pacman.conf
  echo "Removed the Plymouth/SDDM NoExtract rule - run 'sudo pacman -S omarchy-settings' to restore the boot screen."
fi

echo "Done. Run 'pacman -Qtdq' afterwards to check for newly-orphaned deps."
