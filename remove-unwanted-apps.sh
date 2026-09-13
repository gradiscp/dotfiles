#!/bin/bash
# Strip apps from the stock Omarchy set that aren't wanted here.
set -e

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
# Only names that are actually installed: pacman aborts the whole -Rns
# transaction if a single one is missing, so the old fixed list followed by
# `|| true` silently removed nothing at all on every re-run.
installed=$(pacman -Qq "${unwanted[@]}" 2>/dev/null || true)
if [[ -n $installed ]]; then
  # -Rns also takes the dependencies nothing else needs any more (opencv, deno, ...).
  # shellcheck disable=SC2086
  sudo pacman -Rns --noconfirm $installed
fi

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

# Boot/login screen: `omarchy plymouth set by theme crimson-core` writes its
# result into /usr/share/{plymouth,sddm}/themes/omarchy/, but those files are
# owned by the omarchy-settings package, so every update of it silently puts
# the stock screen back (happened with 4.0.1 -> 4.0.3 on 2026-09-10). NoExtract
# keeps pacman's hands off them. Undo: delete these lines, `sudo pacman -S
# omarchy-settings`. Run `omarchy plymouth set by theme crimson-core`
# afterwards to (re)apply the theme itself.
if ! grep -qF 'usr/share/plymouth/themes/omarchy/*' /etc/pacman.conf; then
  sudo cp -a /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%s)"
  sudo sed -i '/^\[options\]/a\\n# Plymouth/SDDM carry the crimson-core boot screen; keep updates from resetting it.\nNoExtract   = usr/share/plymouth/themes/omarchy/* usr/share/sddm/themes/omarchy/*' /etc/pacman.conf
fi

echo "Done. Run 'pacman -Qtdq' afterwards to check for newly-orphaned deps."
