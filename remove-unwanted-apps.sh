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
      ~/.local/share/applications/X.desktop

update-desktop-database ~/.local/share/applications 2>/dev/null || true
echo "Done. Run 'pacman -Qtdq' afterwards to check for newly-orphaned deps."
