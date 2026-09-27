# Cheatsheet

Befehle, die ich brauche. Neue Themen einfach als eigenen Abschnitt unten
anhängen.

## System aktualisieren

| Wann | Befehl | Was es tut |
|---|---|---|
| wöchentlich | `omarchy update` | Snapshot, `pacman -Syu`, AUR, mise-Tools, Omarchy-Migrationen, Drift-Check. Neustart annehmen, wenn Kernel oder Hyprland dabei war. |
| danach, kurz | `sudo pacdiff` | Geänderte Configs in `/etc` (`.pacnew`) zusammenführen. Meist leer. |
| danach, kurz | Clone-Check, siehe unten | Zeigt, ob Omarchy Plugins geändert hat, die hier als Kopie liegen. |
| alle paar Wochen | `docker pull redis:7-alpine python:3.12-slim` | Docker-Basis-Images holen. Danach im jeweiligen Projektordner `docker compose build --pull`. |
| alle paar Monate | `omarchy-update-firmware` | BIOS/SSD-Firmware über fwupd. Der erste Lauf installiert fwupd. |

**Nicht** `sudo pacman -Syu` direkt: Omarchy blockt das mit einem pacman-Hook
("Woah partner"), und dabei fehlten Snapshot, Migrationen, AUR und mise.

`omarchy update` holt die Arch-Pakete von `stable-mirror.omarchy.org`, also
Omarchys getesteten Stand - etwas später als Arch selbst, aber vollständig.
Kanal ansehen: `omarchy-channel-current` (`stable`; `rc`/`edge` wären neuer,
aber ungetestet).

### Clone-Check

Diese Dateien in den eigenen Plugin-Kopien sind identisch mit Omarchys
Original und gehen dessen Updates nicht mit. Keine Ausgabe = alles gleich;
eine `differ`-Zeile = Omarchy hat die Datei geändert, dann nachziehen.

```bash
P=~/.config/omarchy/plugins; S=/usr/share/omarchy/shell/plugins
diff -q $P/gradiscp.notifications/Service.qml        $S/notifications/Service.qml
diff -q $P/gradiscp.notifications/NotificationLogic.js $S/notifications/NotificationLogic.js
diff -q $P/gradiscp.idle/IdleModel.js                $S/services/idle/IdleModel.js
```

### Wenn nach einem Update etwas nicht stimmt

| Problem | Befehl |
|---|---|
| Config-Änderung wirkt nicht | `omarchy-drift-check` |
| Hyprland-Fehler | `hyprctl configerrors` |
| Update kaputt, zurück | Beim Booten im Limine-Menü unter „Snapshots“ den Stand vor dem Update wählen (jedes `omarchy update` legt einen an), dort `omarchy snapshot restore` - macht ihn dauerhaft |
| Log des letzten Updates | `less /tmp/omarchy-update.log` |
