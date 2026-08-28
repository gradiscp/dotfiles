#!/bin/bash
# Strip apps from the stock Omarchy set that aren't wanted here.
set -e

sudo pacman -Rns --noconfirm \
  aether cliamp omacut kdenlive localsend moonlight-qt obs-studio pinta xournalpp \
  2>/dev/null || true

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
# The three above are removed because Chromium is uninstalled here (see
# CLAUDE.md) and omarchy-launch-webapp hardcodes a Chromium-family browser
# for every *other* webapp shortcut - they'd just error out otherwise.

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

echo "Done. Run 'pacman -Qtdq' afterwards to check for newly-orphaned deps."
