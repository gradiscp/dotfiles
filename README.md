# dotfiles

Personal [Omarchy](https://omarchy.org/) Linux config for a Samsung Galaxy
Book Pro 360. Covers Hyprland, the Omarchy shell (bar, lock screen, idle
behavior), terminal, Neovim, and a curated app set - meant to bring a fresh
Omarchy install up to the same setup in one script.

For the *why* behind non-obvious choices, known gotchas, and things that
looked right but weren't - see [CLAUDE.md](CLAUDE.md). This file is the
overview; that one is the debugging notes.

## New laptop workflow

1. **Install Omarchy** on the new machine (its own installer, not this
   repo - this repo only customizes an already-installed system).
2. **Clone this repo over HTTPS**, not SSH - the repo is public, so this
   needs no key/auth at all, and works before you've set anything else up:
   ```bash
   git clone https://github.com/gradiscp/dotfiles.git ~/Projects/dotfiles
   ```
3. **Run the installer:**
   ```bash
   cd ~/Projects/dotfiles
   ./install.sh
   ```
   This symlinks everything under `config/` into place, installs the extra
   packages (`packages.txt`), applies GTK/GNOME settings (`gsettings.sh`),
   strips the unwanted stock apps (`remove-unwanted-apps.sh`), re-applies
   the theme so the bar transparency override actually takes effect, and
   restarts the shell/reloads Hyprland.
4. **Check `config/hypr/monitors.lua`** before or right after - the scale
   value is tuned for this laptop's exact panel. Wrong panel, wrong number,
   and everything looks oddly sized until it's fixed.
5. **Manual steps the script can't do:**
   - Copy an existing SSH key into `~/.ssh` (`chmod 600` the private key)
     if you want to `git push` from the new machine - HTTPS clone doesn't
     need this, but pushing changes back does.
   - Fingerprint: skip it, unless the new laptop has different hardware -
     check `libfprint`'s supported-device list first (see CLAUDE.md for
     why this one's a dead end here).
   - Chromium is deliberately not installed (Firefox only) - reinstall it
     manually if Omarchy's webapp shortcuts (WhatsApp/Discord/YouTube/
     Docker) need to work; see CLAUDE.md for why they're broken without it.
6. **Sanity check:** `hyprctl configerrors` should be empty, and
   `omarchy plugin list` should show `gradiscp.lock`/`gradiscp.idle` as
   `enabled` and the stock `omarchy.lock`/`omarchy.idle` as `disabled`.
   If a `gradiscp.*` plugin was edited after this and something doesn't
   look right, remember: those don't hot-reload, `omarchy restart shell`
   is required (see CLAUDE.md).

## What's customized

- **Layout:** `scrolling` (niri-like side-scrolling) instead of dwindle,
  with `column_width = 1.0` so a single window fills the screen. Thin gaps
  (3 inner / 6 outer).
- **Look:** Bibata-Modern-Ice cursor (size 14), rounded corners (10),
  JetBrains Mono Nerd Font everywhere fontconfig reaches - synthetically
  emboldened for a slightly heavier weight - monitor scale 1.25, solid
  black bar.
- **Transparency:** foot terminal, Nautilus (even while focused), Firefox
  window chrome - all via Hyprland `opacity` window rules, not app config.
  Fullscreen windows (`SUPER+F`) also stay translucent
  (`decoration.fullscreen_opacity`), which isn't the Hyprland default.
- **Lock screen:** fully custom (see CLAUDE.md) - live blurred screenshot
  background, no visible password field or clock, just a lock-in-a-circle
  that goes red/green on wrong/right password. Two lock keybinds with
  different display-blank behavior (see below).
- **Screenshots:** clipboard only by default, no file spam in `~/Pictures`.
- **Browser:** Firefox only - Chromium was removed. This broke Omarchy's
  Chromium-backed webapp shortcuts (WhatsApp, Discord, YouTube), so those
  were removed too. `Docker.desktop` was kept - it runs `lazydocker` in a
  terminal and never needed Chromium.
- **Apps:** trimmed down from the stock Omarchy set - see `packages.txt`
  and `remove-unwanted-apps.sh` for exactly what's gone and why.
- **No fingerprint setup** - this laptop's EgisTec EH57E has no
  production-ready Linux driver (only an experimental one-machine
  proof of concept). See CLAUDE.md before retrying.

## Keybinds changed from Omarchy defaults

| Key | Action | Was |
|---|---|---|
| `SUPER` (tap alone) | Omarchy menu | — |
| `SUPER+SPACE` | *(unbound)* | Omarchy menu |
| `SUPER+L` | Lock, screen stays on | Toggle workspace layout |
| `SUPER+SHIFT+L` | Lock, screen off after 5s | — |
| `SUPER+CTRL+L` | *(unbound)* | Lock (screen off) |
| `SUPER+H` | Toggle workspace layout (dwindle/master) | — |
| `SUPER+SHIFT+S` | Screenshot → clipboard only | Google Maps webapp |
| `PRINT` | *(unbound)* | Screenshot |
| `CTRL+SHIFT+ESC` | Shutdown | — |
| `SUPER+CTRL+SHIFT+R` | Reboot | — (plain `CTRL+SHIFT+R` deliberately avoided - that's browser hard-refresh) |

Workspaces 6-8 are pinned as `persistent` so they always show in the bar,
not just once visited. Full list: `omarchy menu keybindings --print`.

⚠️ **`SUPER+H` has a side effect worth knowing:** it saves a *per-workspace*
layout override that silently overrides the global `scrolling` setting for
that workspace only. If tiling suddenly behaves differently on one
workspace, that's why - see CLAUDE.md for the one-line fix.

## Structure

```
config/
  hypr/         Hyprland: bindings, monitors, looknfeel, etc.
  omarchy/
    shell.json              Bar layout, idle timing, plugin toggles
    plugins/gradiscp.lock/  Custom lock screen (clone of omarchy.lock)
    plugins/gradiscp.idle/  Idle service (clone of omarchy.idle) - one
                             fix: doesn't re-lock over an active light lock
    themes/tokyo-night/     Bar color/alpha override
  foot/         Terminal config (font, alpha)
  fontconfig/   Synthetic embolden for JetBrains Mono
  nvim/         Transparent background autocmd
bin/
  omarchy-lock-light   The SUPER+L script (real lock, no display blank)
install.sh               Fresh-machine setup
remove-unwanted-apps.sh  Just the app-trimming part, standalone
gsettings.sh             GTK/GNOME settings (font, cursor, text scaling)
packages.txt             Extra packages + what got removed and why
archive/                 (if present) leftovers from the pre-Omarchy setup
```

## Planned

A second-drive repurposing plan (games/Docker/VM sandbox/backups on the
ex-Windows NVMe) is written up in CLAUDE.md but not executed yet.
