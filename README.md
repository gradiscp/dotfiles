# dotfiles

Personal [Omarchy](https://omarchy.org/) config for a Samsung Galaxy Book Pro
360: Hyprland, the Omarchy shell (bar, notifications, lock screen, idle), the
crimson-core theme, terminal and tools - lean, and reproducible on a new
laptop with one script.

The *why* behind every non-obvious choice, and the gotchas that cost real
debugging time, live in [CLAUDE.md](CLAUDE.md). This file is the overview.

## New laptop

1. Install Omarchy with its own installer.
2. Clone over HTTPS (public repo, no key needed) to the path the scripts
   expect:
   ```bash
   git clone https://github.com/gradiscp/dotfiles.git ~/Projects/paulgradischnig/dotfiles
   cd ~/Projects/paulgradischnig/dotfiles && ./install.sh
   ```
   It asks for the sudo password a few times. It installs `packages.txt`,
   links every config into place, sets the text size, removes the unwanted
   stock apps (`remove-unwanted-apps.sh`), applies the theme, and checks
   that all links point into the repo.
3. Do the manual steps it prints at the end: monitor scale for a different
   panel, SSH key, `sudo tailscale up`, the boot screen
   (`omarchy plymouth set by theme crimson-core`), Firefox Sync.

## Keeping it in sync

Omarchy's own tools sometimes replace a linked config with a plain file.
`omarchy-drift-check` re-links those (when nothing was changed), and reports
real differences, a reset boot screen or lost `NoExtract` lines as a
notification. It runs after every `omarchy update`; run it by hand after
changing settings through Omarchy's menus.

## What's customized

- **Look:** crimson-core theme (colors sampled from the wallpaper), matching
  boot screen, `scrolling` layout, JetBrains Mono, Bibata cursor, scale 1.25,
  translucent foot/Nautilus/Firefox (streaming sites stay solid).
- **Bar:** red pill on the active workspace; a terminal icon that turns red
  with a count while Claude Code sessions wait for a permission.
- **Notifications:** compact and translucent; red only for critical ones.
  Claude permission requests pop up and jump back to their terminal on click.
- **Lock and idle:** `SUPER+L` minimal lock, screen stays on; `SUPER+SHIFT+L`
  full lock with clock, screen off. Screensaver after 4 min, lock after 5;
  audio playback keeps the machine awake.
- **Apps:** Firefox only, trimmed stock set; anything heavier runs in a
  container instead of being installed.

## Keybinds changed from Omarchy defaults

| Key | Action |
|---|---|
| `SUPER+L` | Lock, screen stays on |
| `SUPER+SHIFT+L` | Lock with clock, screen off after 5s |
| `SUPER+H` | Toggle workspace layout (was on `SUPER+L`) |
| `SUPER+P` | Jump to the Claude session waiting for a permission |
| `SUPER+W` | Close window - asks first if a terminal still runs something |
| `SUPER+SHIFT+S` | Screenshot to clipboard (was `PRINT`) |
| `CTRL+SHIFT+ESC` | Shutdown |
| `SUPER+CTRL+SHIFT+R` | Reboot |

Unbound because their target isn't installed: webapp keys, Spotify, Signal,
1Password, Share (`SUPER+CTRL+S`), weather (`SUPER+CTRL+ALT+W`). Full list:
`omarchy menu keybindings --print`.

## Structure

```
config/
  hypr/                Hyprland config (bindings, looknfeel, rules, ...)
  omarchy/
    shell.json         Bar layout, idle timing, plugin list
    plugins/           gradiscp.* - lock, idle, close dialog, workspaces,
                       notifications, Claude status widget
    extensions/        Menu overrides (hidden/redirected dead entries)
    themes/crimson-core/
  claude/              Claude Code settings (hook) and global rules
  foot/ fontconfig/ nvim/ herdr/ git/ mise/ systemd/ mimeapps.list
bin/                   omarchy-lock-light, claude-notify, window-close-guard,
                       omarchy-idle-audio-guard, omarchy-drift-check
install.sh             Fresh-machine setup
remove-unwanted-apps.sh  Removes unwanted packages, stock themes; NoExtract
gsettings.sh           GTK font and cursor
packages.txt           Packages added on top of Omarchy
```

## Planned

Repurposing the second (ex-Windows) NVMe for games, Docker, VMs and backups -
written up in CLAUDE.md, not done yet.
