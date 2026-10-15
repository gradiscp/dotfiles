# Cheatsheet

Befehle, die ich brauche. Neue Themen einfach als eigenen Abschnitt unten
anhängen.

## System aktualisieren

| Wann | Befehl | Was es tut |
|---|---|---|
| wöchentlich | `omarchy update` | Snapshot, `pacman -Syu`, AUR, mise-Tools, Omarchy-Migrationen, Drift-Check. Neustart annehmen, wenn Kernel oder Hyprland dabei war. |
| danach, kurz | `sudo pacdiff` | Geänderte Configs in `/etc` (`.pacnew`) zusammenführen. Meist leer. |
| alle paar Wochen | `docker pull <Basis-Images der Projekte>` | Docker-Basis-Images holen. Danach im jeweiligen Projektordner `docker compose build --pull`. |
| alle paar Monate | `omarchy-update-firmware` | BIOS/SSD-Firmware über fwupd. Der erste Lauf installiert fwupd. |
| bei jedem neuen Git-Repo | `git remote set-url origin git@<ssh-alias>:gradiscp/<repo>.git` | Remote auf den SSH-Host-Alias aus `~/.ssh/config` umstellen, damit der richtige Key greift. |


**Nicht** `sudo pacman -Syu` direkt: Omarchy blockt das mit einem pacman-Hook
("Woah partner"), und dabei fehlten Snapshot, Migrationen, AUR und mise.

`omarchy update` holt die Arch-Pakete von `stable-mirror.omarchy.org`, also
Omarchys getesteten Stand - etwas später als Arch selbst, aber vollständig.
Kanal ansehen: `omarchy-channel-current` (`stable`; `rc`/`edge` wären neuer,
aber ungetestet).

### Wenn nach einem Update etwas nicht stimmt

| Problem | Befehl |
|---|---|
| Config-Änderung wirkt nicht | `omarchy-drift-check` |
| Hyprland-Fehler | `hyprctl configerrors` |
| Update kaputt, zurück | Beim Booten im Limine-Menü unter „Snapshots“ den Stand vor dem Update wählen (jedes `omarchy update` legt einen an), dort `omarchy snapshot restore` - macht ihn dauerhaft |
| Log des letzten Updates | `less /tmp/omarchy-update.log` |
| Skript im dotfiles-Repo geändert | `shellcheck install.sh remove-unwanted-apps.sh bin/*` und `bash -n` darauf |
