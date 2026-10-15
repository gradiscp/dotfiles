# dotfiles

Personal [Omarchy](https://omarchy.org/) config: Hyprland, the Omarchy shell
(bar, notifications, lock screen), terminal and tools - kept as close to
stock as the few things I actually want allow, and reproducible on a new
laptop with one script.

The invariants and the traps that cost real debugging time live in
[CLAUDE.md](CLAUDE.md); the *why* of each change is in its commit message.
Everyday commands (updating the system and more) are in
[CHEATSHEET.md](CHEATSHEET.md). This file is the overview.

## New laptop

1. Install Omarchy with its own installer.
2. Clone over HTTPS (public repo, no key needed). The clone path is free,
   but the symlinks `install.sh` creates bake it in, so pick the final one:
   ```bash
   git clone https://github.com/gradiscp/dotfiles.git ~/Projects/paulgradischnig/dotfiles
   cd ~/Projects/paulgradischnig/dotfiles && ./install.sh
   ```
   It asks for the sudo password a few times and refuses to run as root.
   It installs `packages.txt`, links every config into place, sets the text
   size, GTK font and cursor, keeps only Claude Code of the coding agents Omarchy
   installs via mise, removes the unwanted stock apps and themes
   (`remove-unwanted-apps.sh`), sets Tokyo Night, and checks that all links
   point into the repo.
3. Do the manual steps it prints at the end: laptop scale for a different
   panel, SSH key, `sudo tailscale up --accept-routes`, uBlock Origin and
   Bitwarden in Brave, and
   the untracked per-machine files (`~/.config/git/config.local`,
   `config/claude/rules/*.local.md`).

## Keeping it in sync

Omarchy's own tools sometimes replace a linked config with a plain file, and
a removed package can come back through any install command or menu.
`omarchy-drift-check` re-links the copies (when nothing was changed) and
reports real differences and returned packages as a notification. It runs
after every `omarchy update`; run it by hand after changing settings through
Omarchy's menus.

## What's customized

- **Look:** Tokyo Night (stock), square corners, no blur or transparency,
  `scrolling` layout with 2/3 px gaps, JetBrains Mono Nerd Font for
  everything (UI, terminal, and the generic sans/serif families), Bibata
  cursor at 14 (one 1.7 MB variant, not the 322 MB package).
  Two own themes, `crimson-core` and `apple-coast`, stay selectable.
- **Bar:** the active workspace as a capsule in the theme's urgent colour; a
  terminal icon that lights up with a count while Claude Code sessions wait
  for a permission. No tray.
- **Notifications:** stock. Claude permission requests pop up and jump back
  to their terminal on click.
- **Lock and idle:** stock lock on `SUPER+L`. Screensaver after 5 min, lock
  after 7; a
  fullscreen browser window (a film) keeps the machine awake.
- **Apps:** Brave Origin as the only browser, with privacy defaults as
  managed policies (`config/brave/privacy.json`) and uBlock Origin; trimmed
  stock set (no LibreOffice, Obsidian, mpv, Disks, CJK input); anything
  heavier runs in a container instead of being installed. Only Claude Code
  as a coding agent.

## Keybinds changed from Omarchy defaults

| Key | Action |
|---|---|
| `SUPER+L` | Lock (stock `SUPER+CTRL+L` unbound) |
| `SUPER+H` | Toggle workspace layout (was on `SUPER+L`) |
| `SUPER+P` | Jump to the Claude session waiting for a permission |
| `SUPER+W` | Close window - asks first if a terminal still runs something |
| `SUPER+SHIFT+S` | Screenshot to clipboard (was `PRINT`) |
| `CTRL+SHIFT+ESC` | Shutdown |
| `SUPER+CTRL+SHIFT+R` | Reboot |

Unbound because the app is not wanted (stock would offer to install it):
webapp keys, Spotify, Signal, 1Password, Obsidian, cliamp,
Share (`SUPER+CTRL+S`), weather (`SUPER+CTRL+ALT+W`). Full list:
`omarchy menu keybindings --print`.

## Structure

```
config/
  hypr/                Hyprland overrides (bindings, looknfeel, monitors)
  omarchy/
    shell.json         Bar layout, idle timing, plugin list
    plugins/           gradiscp.* - close dialog, workspaces, Claude status
    extensions/        Menu override (Share hidden, needs localsend)
    themes/            crimson-core, apple-coast (own themes, selectable)
  brave/               Privacy policies, launch flags, uBlock Origin backup
  claude/              Claude Code settings (hooks), global rules, own skills
  fontconfig/ herdr/ git/ mise/ mimeapps.list
bin/                   claude-notify, window-close-guard, omarchy-drift-check,
                       git-all (status/fetch/pull/push over every repo below)
install.sh             Fresh-machine setup
remove-unwanted-apps.sh  Removes unwanted packages and stock themes (--check
                       only reports); NoExtract keeps updates from restoring them
packages.txt           Packages added on top of Omarchy
```
