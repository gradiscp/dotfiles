# dotfiles

Personal [Omarchy](https://omarchy.org/) config: Hyprland, the Omarchy shell
(bar, notifications, lock screen), terminal and tools - kept as close to
stock as the few things I actually want allow, and reproducible on a new
laptop with one script.

The invariants and the traps that cost real debugging time live in
[CLAUDE.md](CLAUDE.md); the *why* of each change is in its commit message.
Everyday commands (updating the system and more) are in
[CHEATSHEET.md](CHEATSHEET.md). This file is the overview.

## Principles

Every change to this repo, and every suggestion for one, is measured against
these, in this order:

1. **Stock first.** Omarchy's defaults are the baseline. A customisation
   earns its place only if it does something stock cannot and I actually use
   it; styling alone does not qualify. Prefer a setting over a file, a file
   over a script, a script over a plugin, and a one-line override over a
   copy of stock code (copies never receive upstream fixes).
2. **Lightweight.** Nothing installed "just in case". Packages, launchers and
   keybinds for things I do not use go, and `remove-unwanted-apps.sh` keeps
   them gone. Tools that are not desktop config live in containers or in
   `mise`, not as system packages.
3. **Secure and private.** The repo is public: no identities, hosts, tokens
   or project names, ever (per-machine files are untracked). Scripts
   validate what they pass to the shell, downloads are pinned and checked,
   Claude Code is denied the credential stores, the browser runs with
   privacy policies.
4. **Simple to reason about.** One list of links (`install.sh`), one check
   that they hold (`omarchy-drift-check`), docs that describe the present
   and leave history to `git log`. If a mechanism needs a paragraph to
   justify itself, it is probably too much.
5. **Reproducible.** A fresh Omarchy plus `./install.sh` must yield this
   machine; anything that is set by hand is listed in the cheatsheet.

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
3. Do the manual steps it prints at the end: log in again, laptop scale
   for a different panel, SSH key and host alias, the Tailscale, GitHub and
   Claude logins, the Brave hand-set items from the cheatsheet, and the
   untracked per-machine files (`~/.config/git/config.local` with the
   identity files it includes, `config/claude/rules/*.local.md`).
   On an installation older than a few days, run `omarchy update` first.

## Keeping it in sync

After every `omarchy update` two hooks run. `remove-unwanted-apps.sh` takes
out whatever the update brought back (packages, launchers, coding-agent
wrappers, stock themes). Then `omarchy-drift-check` re-links configs that
Omarchy's tools turned into plain copies and reports anything still off as a
notification. Both can be run by hand any time, e.g. after changing settings
through Omarchy's menus.

## What's customized

- **Look:** Tokyo Night (stock), square corners, no blur, stock opacity,
  `scrolling` layout with 2/3 px gaps, JetBrains Mono Nerd Font for
  everything that names no font (UI, terminal, the generic sans/serif
  families), Bibata cursor at 14 (one small download, not the 322 MB package).
  Stock themes kept besides it: Ethereal, Kanagawa (with an own Big Sur
  coast background) and Vantablack; the other stock themes are removed.
- **Bar:** thinner than stock (22 px); the active workspace as a capsule in
  the theme's urgent colour; a
  terminal icon that lights up with a count while Claude Code sessions wait
  for a permission; media controls while something plays, microphone mute
  and Tailscale. No tray, weather, indicators, display or menu button.
- **Notifications:** stock. Claude permission requests pop up and jump back
  to their terminal on click.
- **Lock and idle:** stock lock on `SUPER+L`. Screensaver after 5 min, lock
  after 7; a fullscreen browser window (a film) keeps the machine awake.
- **Apps:** Brave Origin as the only browser, with privacy defaults as
  managed policies (`config/brave/privacy.json`) and uBlock Origin; trimmed
  stock set (no LibreOffice, Obsidian, mpv, Disks, CJK input, tmux,
  lazydocker, lazygit, screen recorder, Evince: PDFs open in Papers);
  anything heavier runs in a
  container instead of being installed. Only Claude Code as a coding agent.

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
Share (`SUPER+CTRL+S`), weather (`SUPER+CTRL+ALT+W`), OCR
(`SUPER+CTRL+PRINT`, needs tesseract), tmux (`SUPER+ALT+RETURN`,
`SUPER+ALT+K`; herdr instead), Docker TUI (`SUPER+SHIFT+D`), screen
recording (`ALT+PRINT`). Full list:
`omarchy menu keybindings --print`.

## Structure

```
config/
  hypr/                Hyprland overrides (bindings, looknfeel, monitors)
  omarchy/
    shell.json         Bar layout, idle timing, plugin list
    shell.toml         Shell values over every theme: font size, thinner bar
    plugins/           gradiscp.* - close dialog, workspaces, Claude status
    extensions/        Menu override (Share hidden, needs localsend)
    backgrounds/       Own background for the stock Kanagawa theme
  brave/               Privacy policies, launch flags, uBlock Origin backup
  environment.d/       Masks Omarchy's fcitx input-method variables
  claude/              Claude Code settings (hooks), global rules, own skills
  nvim/                One plugin on top of Omarchy's LazyVim: Markdown rendering
  fontconfig/ herdr/ git/ mise/ mimeapps.list
bin/                   claude-notify, window-close-guard, omarchy-drift-check,
                       git-all (status/fetch/pull/push over every repo below)
install.sh             Fresh-machine setup
remove-unwanted-apps.sh  Removes unwanted packages and stock themes (--check
                       only reports); NoExtract keeps updates from restoring them
packages.txt           Packages added on top of Omarchy
```

## Third-party content

The wallpaper under `config/omarchy/backgrounds/` is not covered by this
repo's MIT licence: it belongs to its owner and is kept here only as a
personal desktop background.
