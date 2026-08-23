# dotfiles

Omarchy Linux config for a Samsung Galaxy Book Pro 360. This file is notes
for whoever (human or Claude) touches this repo next - the *why* behind
non-obvious choices, and known gotchas that cost real debugging time.

`archive/endeavouros-kde/` is the leftover archinstall config from this
machine's previous EndeavourOS+KDE setup - kept for reference, not live
config for anything.

**History was rewritten on 2026-08-23** with `git filter-repo` to strip a
committed `user_credentials.json` (contained this user's login password
hash - the repo is public on GitHub, so that hash should be treated as
already compromised regardless of the history rewrite; the password itself
should be changed) and several large `.knsv` files that had bloated
`.git` to 141MB (down to ~7MB after). Anyone with an existing clone or fork
needs to re-clone rather than pull - the old history is gone from `origin`
after the force-push, but their local copy still has the old commits.

## Hardware / dead ends

- Fingerprint sensor is an **EgisTec EH57E**. No libfprint driver exists
  (checked upstream libfprint and every AUR `libfprint-2-tod1-*` package -
  Goodix/Elan/Synaptics/Broadcom all have one, EgisTec doesn't). Don't
  reinstall `libfprint`/`fprintd`/`usbutils` expecting it to suddenly work.
- Panel is 1920x1080 on the built-in eDP-1.

## Gotchas found the hard way

- **Monitor scale must be set via `omarchy hyprland monitor scaling <N>`**,
  not by hand-editing `hypr/monitors.lua`. A raw file edit got silently
  reset back to the old value at some point - the CLI command persists
  correctly, a manual edit may not.
- **foot's `alpha` option belongs under `[colors-dark]` (or `[colors]`),
  not `[main]`** - foot errors "not a valid option" if you put it in
  `[main]`, and warns "deprecated, use [colors-dark]" if you use the
  generic `[colors]` name while a `[colors-dark]` section is already
  active (which it is here, via the theme's `include=`).
- **Bar transparency has two different knobs, don't confuse them:**
  - `shell.json`'s `bar.transparent: true/false` is all-or-nothing (fully
    see-through vs the theme's solid color), and **double-clicking the
    bar's center area toggles it** - that's a built-in Omarchy gesture, not
    a bug, and it's why this flips back on its own sometimes.
  - For a *partial* translucent bar, leave `transparent: false` and instead
    set `background-alpha` in the theme's `[bar]` section (0.0-1.0). There
    is no shipped standalone `shell.toml` to overlay from - it's generated
    from `/usr/share/omarchy/default/themed/shell.toml.tpl` at theme-apply
    time. To override it: copy the *generated* file from
    `~/.local/state/omarchy/current/theme/shell.toml` into
    `~/.config/omarchy/themes/<theme-slug>/shell.toml`, edit
    `background-alpha` there, then `omarchy theme set <theme>` again to
    re-apply. (The template comment literally says "Themes can ship
    themes/<name>/shell.toml to replace this generated file.")
- **Cloning a `kind: bar` plugin is broken** in this Omarchy version.
  `omarchy plugin clone omarchy.bar` + switching `shell.json`'s `bar.id` to
  the clone makes the entire bar disappear (confirmed even with a
  byte-identical, unedited clone). Root cause traced in
  `/usr/share/omarchy/shell/shell.qml`: the default bar gets `omarchyPath`/
  `barWidgetRegistry`/`barConfig` as declarative property initializers on
  an inline `Component`, which satisfies QML's `required property`
  contract. A cloned bar loads via `Loader { source: url }` instead, and
  gets those same `required property` values assigned *after* creation via
  plain JS (`shell.configureBar()`) - which does not satisfy `required
  property` for a dynamically-loaded component. Result: silent creation
  failure, empty bar layer, `shell.qml`'s own error-fallback path is also
  broken (`ReferenceError: errorString is not defined`), so nothing is even
  shown to explain it. **Cloning `bar-widget` or `service` kind plugins
  works fine** (e.g. `omarchy.lock` below) - the bug is specific to the
  `bar` kind's `Loader`/`required property` combination.
- **Fullscreen (`SUPER+F`) forces window opacity back to solid** regardless
  of any per-window `opacity` rule - Hyprland has a separate
  `decoration.fullscreen_opacity` setting for this, set in `looknfeel.lua`.
- **`omarchy-launch-webapp` hardcodes a Chromium-family browser.** It reads
  the default browser via `xdg-settings`, but only recognizes
  `google-chrome|brave|microsoft-edge|opera|vivaldi|helium` - anything else
  (including Firefox) falls through to `chromium.desktop`. **Chromium has
  been uninstalled here**, so any remaining webapp shortcut
  (WhatsApp/Discord/YouTube/Docker) is currently broken until either
  Chromium comes back or Omarchy adds Firefox SSB support.
- **Firefox's window opacity actually works via a plain Hyprland
  `o.window(..., {opacity=...})` rule** - unlike Chromium (own Aura
  toolkit, no real Wayland CSD transparency support), Firefox is a real
  GTK/Wayland client-side-decorated window, so the same trick that works
  for foot/Nautilus works for it too. True Chromium window transparency
  isn't attempted here on purpose - the known hack
  (`--enable-transparent-visuals --disable-gpu-compositing`) disables GPU
  acceleration and is known to render corrupted/black.

## Custom keybinds (see `config/hypr/bindings.lua`)

- **Bare tap of `SUPER`** (not `SUPER+SPACE` anymore) opens the Omarchy
  menu, via `SUPER + SUPER_L` with `{ release = true }`.
- **`SUPER+L`** = "light" lock via `~/.local/bin/omarchy-lock-light`:
  real password-gated session lock, display **never blanks**. Was
  previously "Toggle workspace layout" (dwindle/master) - moved to
  `SUPER+H`.
- **`SUPER+SHIFT+L`** = full lock (`omarchy-system-lock`, stock), display
  blanks after 5s. The default `SUPER+CTRL+L` bind for this is unbound -
  only SHIFT+L is used.
- **`SUPER+SHIFT+S`** = screenshot (was `PRINT`, now unbound).

### Lock screen design (`config/omarchy/plugins/gradiscp.lock/`)

A clone of the `omarchy.lock` service plugin, deliberately minimal:
- **Background is a live screenshot of the desktop at the moment of
  locking** (`grim`, captured in `Service.qml`'s `beginLock()` before the
  session-lock surface takes over rendering - can't screenshot after that
  point, app content is no longer composited), lightly blurred - not the
  static theme wallpaper Omarchy uses by default.
- **No visible chrome at all**: no password field box, no placeholder
  text, no clock. Just a circle with a lock icon (`lock-icon.svg`,
  inline-drawn, not an emoji/nerd-font glyph - both were explicitly
  rejected in favor of a plain line-art padlock) centered on screen.
- **Typing is blind** - no password dots, like a terminal `sudo` prompt.
  The circle blips invisible for ~120ms per keystroke as the only typing
  feedback, then on Enter: green border + 350ms flash on correct password
  (via `Service.qml`'s `unlockSucceeded` property, which delays the actual
  `finishUnlock()` so the flash is visible at all - PAM auth completing
  would otherwise tear down the overlay in the same frame), red border on
  wrong password.
- `noBlank` flag (`~/.local/state/omarchy/toggles/lock-no-blank`, set by
  `omarchy-lock-light` before locking, cleared by `Service.qml` on every
  unlock) suppresses the plugin's own 5-second post-lock display-blank
  timer for SUPER+L specifically.
- **Dead end, don't repeat:** a passwordless "privacy cover" panel
  (`gradiscp.privacycover`, since deleted/disabled) was built first,
  showing the same blurred screenshot+icon but dismissible by any
  key/click with zero authentication. This was based on a
  misreading - "not like here 'type password'" meant hide the *visible
  label*, not remove the *actual password requirement*. If asked for a
  passwordless screen again, confirm explicitly first; it's a real,
  security-relevant distinction, not a styling detail.
- Locking never affects background processes (Docker etc.) either way -
  Wayland session lock only blocks input/shows the overlay, it doesn't
  suspend anything.

### Idle behavior (`config/omarchy/plugins/gradiscp.idle/`)

Clone of `omarchy.idle`. One change: `lockSystem()` now checks
`omarchy-shell lock isLocked` before calling `omarchy-system-lock` again -
without this, being idle past the 5-minute `idle.lock` mark while already
light-locked (`SUPER+L`) would trigger a second, full lock call that
*does* blank the display, defeating the whole point of the light lock.
Mirrors the guard the stock screensaver path already had.

`idle.screensaver` in `shell.json` is 120s (2 min) - triggers Omarchy's
built-in `ttfx`-based terminal screensaver, unrelated to the lock screen
above. `idle.lock` stays at 300s (5 min, stock default).

### Plugin hot-reload gotcha (cost real debugging time)

**`service` and `panel` kind plugins do NOT hot-reload on file save**,
unlike `bar-widget` plugins (which `plugins.md` correctly says do).
`omarchy-shell shell rescanPlugins` only updates the plugin *registry*
(new/removed plugins), not the compiled QML of an already-running
instance. After editing anything in `gradiscp.lock/` or `gradiscp.idle/`,
**`omarchy restart shell` is required** - skipping this silently runs the
stale pre-edit code with no error, which looks exactly like the edit
having no effect.

### Workspaces

Workspaces 6-8 are marked `persistent` in `hyprland.lua` so they always
show in the bar's workspace indicator instead of only appearing once
visited.

## Removed from the stock Omarchy app set

Real packages: `aether`, `cliamp`, `omacut`, `kdenlive`, `localsend`,
`moonlight-qt`, `obs-studio`, `pinta`, `xournalpp`, `chromium` (+ ~18
packages that became orphaned afterward, also removed). Webapp shortcuts
(just `.desktop` files, never real packages): Basecamp, HEY, Zoom, the 4
Google webapps, X/Twitter.

## Planned: repurpose the second NVMe (ex-Windows, ~477GB) drive

Not done yet - this is the plan for when it's time to pull the trigger.
**Wiping this drive is destructive and needs an explicit go-ahead when
actually executed** - this section is prep, not a standing authorization.

Current state: `nvme0n1` is a separate physical drive from the main Linux
install (`nvme1n1`, LUKS + btrfs + snapper). Windows' usual layout (EFI,
MSR, NTFS, recovery partitions) - all disposable, nothing there is needed.

Plan: wipe it, LUKS-encrypt it to match the main drive's setup, format
btrfs, one subvolume per purpose so each can be snapshotted/rolled back
independently:

- `@games` - Steam library (`steamlibrary` or a symlinked `~/Games`).
  Keeps large game installs off the main 930GB drive.
- `@docker` - Docker's `data-root` pointed here (`/etc/docker/daemon.json`
  `"data-root"`), so container images/volumes stop competing with the main
  drive's snapshot space.
- `@sandbox` - distrobox/toolbox containers and libvirt/QEMU VM disk images.
  This covers "try another distro" far more practically than a real
  dual-boot partition: spin up an Arch/Fedora/Debian distrobox or a VM,
  break it freely, `rm -rf` it when done, main system untouched throughout.
- `@backup` - `btrfs send/receive` target for the main drive's snapper
  snapshots. A second physical drive is what actually makes a snapshot a
  backup instead of just an undo button on the same disk.
- `@media` - overflow storage / future self-hosting (photos via Immich,
  etc.) if that ever becomes a real project instead of a maybe.

Mount at `/mnt/data` (or similar) via `/etc/fstab`, referenced by UUID.
Encrypting it the same way as the main drive means one LUKS passphrase
prompt at boot unlocks both (keyfile-in-header, same pattern the main
install already uses) rather than two separate prompts.

## Syncing to a new machine

`install.sh` symlinks everything under `config/` into place and installs
`packages.txt`. `remove-unwanted-apps.sh` re-applies the app cleanup above.
Still manual: review `config/hypr/monitors.lua` scale for the new panel,
copy an SSH key into `~/.ssh`, and re-run `omarchy theme set tokyo-night`
once so the `background-alpha` overlay actually takes effect (the theme
overlay files don't do anything just by existing on disk).
