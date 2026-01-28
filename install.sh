#!/bin/bash

# Abbruch bei Fehler
set -e

echo "### Starte Installation ###"

# 1. System updaten
sudo pacman -Syu --noconfirm

# 2. Yay (AUR Helper) installieren - WICHTIG für Hyprland
if ! command -v yay &>/dev/null; then
  echo "-> Installiere yay..."
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
else
  echo "-> yay ist schon installiert."
fi

# 3. Pakete aus Liste installieren
echo "-> Installiere Pakete..."
# Wir nutzen yay statt pacman, damit auch AUR Pakete gehen
yay -S --needed --noconfirm - <pkglist.txt

# 4. Configs verlinken (Stow) - Das machen wir im nächsten Schritt
# stow .

echo "### Fertig! Bitte neu starten oder Hyprland starten. ###"
