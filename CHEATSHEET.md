# Cheatsheet

Befehle, die ich brauche. Neue Themen einfach als eigenen Abschnitt unten
anhängen.

## System aktualisieren

| Wann | Befehl | Was es tut |
|---|---|---|
| wöchentlich | `omarchy update` | Snapshot, `pacman -Syu`, Omarchy-Migrationen, Drift-Check, dann AUR und mise-Tools. Neustart annehmen, wenn Kernel oder Hyprland dabei war. |
| danach, kurz | `sudo pacdiff` | Geänderte Configs in `/etc` (`.pacnew`) zusammenführen. Meist leer. |
| nach Änderungen über Omarchy-Menüs | `omarchy-drift-check` | Läuft nach `omarchy update` automatisch; von Hand prüfen, ob alle Configs noch ins Repo zeigen, Theme-Sperre und Pakete stimmen. Ergebnis als Toast, Log in `~/.local/state/omarchy-drift-check.log`. |
| nach jedem Update (automatisch) | `bash ~/Projects/paulgradischnig/dotfiles/remove-unwanted-apps.sh` | Läuft als Hook nach `omarchy update`: entfernt, was das Update an unerwünschten Paketen, Launchern, Agent-Wrappern und Themes zurückgebracht hat. Von Hand jederzeit; `--check` zeigt nur an. |
| alle paar Wochen | `docker pull <Basis-Images der Projekte>` | Docker-Basis-Images holen. Danach im jeweiligen Projektordner `docker compose build --pull`. |
| alle paar Monate | `omarchy-update-firmware` | BIOS/SSD-Firmware über fwupd. Der erste Lauf installiert fwupd. |
| bei jedem neuen Git-Repo | `git remote set-url origin git@<ssh-alias>:gradiscp/<repo>.git` | Remote auf den SSH-Host-Alias aus `~/.ssh/config` umstellen, damit der richtige Key greift. |


**Nicht** `sudo pacman -Syu` direkt: Omarchy blockt das mit einem pacman-Hook
("Woah partner"), und dabei fehlten Snapshot, Migrationen, AUR und mise.

`omarchy update` holt die Arch-Pakete von `stable-mirror.omarchy.org`, also
Omarchys getesteten Stand - etwas später als Arch selbst, aber vollständig.
Kanal ansehen: `omarchy-channel-current` (`stable`; `rc`/`edge` wären neuer,
aber ungetestet).

### Brave Origin: was keine Policy setzt (einmal pro Laptop)

`config/brave/privacy.json` setzt die meisten Datenschutz-Einstellungen als
Policy (im Browser gesperrt, Gebäude-Symbol). Von Hand bleiben:

| Wo | Was |
|---|---|
| `brave://settings/shields` | Tracker & Werbung auf "Aggressiv"; "Store contact information for broken site reports" aus |
| `brave://settings/appearance` | Page zoom 80 % (Seiten passen so zur Oberfläche bei Scale 1; keine Policy dafür) |
| `brave://settings/search` | Suchmaschine nach Wahl (absichtlich keine Policy, sonst gesperrt) |
| `brave://settings/extensions/v2` | uBlock Origin einschalten (Brave hostet die volle Manifest-V2-Version) |
| uBlock-Dashboard, Reiter Settings | "Restore from file": `config/brave/ublock-origin-backup.txt` (Filterlisten-Auswahl) |
| `brave://settings/extensions` | Bitwarden |
| Omarchy-Netzwerk-Panel | DNS-Provider Cloudflare oder Quad9 (gilt systemweit, nicht nur im Browser) |

### Wenn nach einem Update etwas nicht stimmt

| Problem | Befehl |
|---|---|
| Config-Änderung wirkt nicht | `omarchy-drift-check` |
| Hyprland-Fehler | `hyprctl configerrors` |
| Update kaputt, zurück | Beim Booten im Limine-Menü unter „Snapshots“ den Stand vor dem Update wählen (jedes `omarchy update` legt einen an), dort `omarchy snapshot restore` - macht ihn dauerhaft |
| Log des letzten Updates | `less /tmp/omarchy-update.log` |

### Dotfiles-Repo (öffentlich)

| Wann | Befehl |
|---|---|
| Skript geändert | `shellcheck install.sh remove-unwanted-apps.sh bin/*` und `bash -n` darauf |
| vor jedem Commit | `git diff` lesen: Tools schreiben durch die Links ins Repo (CLAUDE.md, "Write-through writers"); `git add <Pfade>`, nicht `-A` |
| vor jedem Push | `git grep -niE 'svag\|fortnitepro\|privat\|/home/' HEAD` muss leer sein |

### Sicherheit (Viren, bekannte Lücken)

| Wann | Befehl | Was es tut |
|---|---|---|
| USB-Stick von fremdem / Windows-Rechner | `clamscan -r -i /run/media/$USER/<Stick>` | Virenscan, meldet nur. Mit `--move=$HOME/quarantine` werden Funde dorthin verschoben. Nie `--remove` (Fehlalarme). ~1 GB RAM, nie mehrere gleichzeitig. |
| Downloads, ab und zu | `clamscan -r -i ~/Downloads` | wie oben |
| einzelne verdächtige Datei | virustotal.com | ~70 Scanner auf einmal; nichts Vertrauliches hochladen |
| nach `omarchy update`, ab und zu | `arch-audit -u` | Installierte Pakete mit bekannter Lücke, für die es schon ein Update gibt; leer = nichts zu tun. Ohne `-u` auch die ohne Fix. |
| im Projektordner (wie Dependabot) | `osv-scanner scan source -r .` | Prüft die Lockfiles (npm, uv/pip, ...) gegen osv.dev. Schickt Paketnamen und Versionen dorthin, keinen Code. |

Die ClamAV-Signaturen aktualisiert `clamav-freshclam-once.timer` täglich;
Stand: `clamscan --version`. Kein `clamd`-Daemon (dauerhaft 1,6 GB+ RAM).

### Github gh 

| Wann | Befehl |
| -------------- | --------------- |
| Account switchen von gh | gh auth switch --user gradiscpsvag |

