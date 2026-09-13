#!/bin/bash
# GTK/GNOME settings that Omarchy's own configs don't cover.
set -e

gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
# text-scaling-factor is deliberately NOT set here: `omarchy display text size`
# (run by install.sh) drives it together with the shell font size and the
# terminal font, and a fixed 1.0 here would undo that.
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 14
gsettings set org.gnome.desktop.wm.preferences button-layout ''
