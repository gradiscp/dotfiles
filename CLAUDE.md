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

- Fingerprint sensor is an **EgisTec EH57E, USB ID `1c7a:057e`**. No
  packaged/mainline libfprint driver exists (checked upstream libfprint and
  the AUR `libfprint-2-tod1-*` / `libfprint-egismoc-sdcp-git` packages -
  those cover *different* EgisTec USB IDs, `0583`/`0584`/`0587`, not this
  one). There IS an experimental driver for this exact chip:
  [Cruise42/eh57e-linux-driver](https://github.com/Cruise42/eh57e-linux-driver)
  - explicitly "not production-ready", tested on exactly one machine
  (Linux Mint, not Arch/Omarchy), no AUR package, requires manually
  patching and rebuilding libfprint from source. Decided not worth the
  risk/effort for a password-based login that already works fine - if
  revisiting this, build it isolated under `/opt` per its own docs, don't
  replace the system libfprint.
- Panel is 1920x1080 on the built-in eDP-1.
- **Git identity: global config (`gradiscp` / `fortnitepro06@yahoo.com`)
  is correct and intentional** - don't set a local `user.name`/`user.email`
  override in this repo "fixing" it to something else. That happened once
  during setup (an assistant used a different name/email from elsewhere in
  its context) and looked like the config "kept reverting" when it was
  actually the local override fighting the correct global value.

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
    **Note the word *replace*** - it is not merged into the generated file,
    so an overlay means owning all ~200 lines forever. `crimson-core`
    deliberately ships none; the previous `tokyo-night/shell.toml` overlay
    was deleted along with that theme.

    A `shell.<section>.toml` file (e.g. `shell.bar.toml`) *is* merged into
    just that one section - see `apply_shell_section_overrides` in
    `omarchy-theme-set-templates`. That is the cheap way to change one knob
    like `background-alpha` without owning the whole file.
- **Nothing in `~/.config/hypr/` is a symlink either** - all six `.lua`
  files are plain copies (checked 2026-08-28: not one is a link, i.e.
  `install.sh` has never actually run on this machine, or something replaced
  them since). Their content still matched the repo byte-for-byte, so
  nothing had been lost - but **editing the repo file alone changes
  nothing live**, and `hyprctl reload` will happily report success while
  running the old config. That cost real debugging time once: a binding
  edited in the repo simply never appeared in `hyprctl binds`. Until this is
  converted to real symlinks, treat it like `shell.json` below and copy in
  both directions: `cp config/hypr/<f>.lua ~/.config/hypr/` after a repo
  edit, and back after using an `omarchy hyprland ...` CLI command (those
  write the live file). Verify with `hyprctl binds` / `hyprctl configerrors`,
  never by assuming.
- **`shell.json` does not stay a symlink.** `install.sh` links
  `~/.config/omarchy/shell.json` into this repo, but the live file was found
  as a plain `-rw-------` regular file with content the repo copy never had
  (a changed `clock.format`), i.e. something rewrote the path rather than
  writing through the link - the `omarchy bar` commands and the shell's own
  settings UI both persist to this file. So **after changing anything in the
  bar/idle config, copy the live file back into the repo** rather than
  assuming the symlink carried it:
  `cp ~/.config/omarchy/shell.json config/omarchy/shell.json`.
- **There is no `omarchy bar remove`.** `omarchy bar --help` lists
  `use/reset/defaults/position/transparent/put/move/set` only - taking a
  widget *out* of the bar means deleting its entry from `bar.layout` in
  `shell.json` by hand. It hot-reloads on save, no restart needed.
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
  been uninstalled here**, so every webapp shortcut that went through it
  (WhatsApp/Discord/YouTube) errored out with `Path "--app=..." does not
  exist!` - those three `.desktop` files were deleted rather than
  reinstalling Chromium. **`Docker.desktop` was deliberately kept**: it
  runs `lazydocker` in a terminal, never touches `omarchy-launch-webapp`,
  so it was never affected. If a webapp shortcut is ever wanted again,
  either reinstall Chromium as a silent runtime or just use a normal
  Firefox tab/bookmark.
- **Firefox's window opacity actually works via a plain Hyprland
  `o.window(..., {opacity=...})` rule** - unlike Chromium (own Aura
  toolkit, no real Wayland CSD transparency support), Firefox is a real
  GTK/Wayland client-side-decorated window, so the same trick that works
  for foot/Nautilus works for it too. True Chromium window transparency
  isn't attempted here on purpose - the known hack
  (`--enable-transparent-visuals --disable-gpu-compositing`) disables GPU
  acceleration and is known to render corrupted/black.

## Custom keybinds (see `config/hypr/bindings.lua`)

- **Bare tap of `SUPER`** opens the Omarchy menu, via `SUPER + SUPER_L`
  with `{ release = true }` - **in addition to** the stock `SUPER+SPACE`,
  which works too. `SUPER+SPACE` was unbound here for a while; it isn't
  anymore. The bare-tap bind is a *release* bind on the modifier itself, and
  Hyprland only fires it when no other bind ran while Super was held - which
  is why `SUPER+SPACE`, `SUPER+1`, `SUPER+L` etc. don't also pop the menu
  when you let go of Super.
- **`SUPER+L`** = "light" lock via `~/.local/bin/omarchy-lock-light`:
  real password-gated session lock, display **never blanks**. Was
  previously "Toggle workspace layout" (dwindle/master) - moved to
  `SUPER+H`.
- **`SUPER+SHIFT+L`** = full lock (`omarchy-system-lock`, stock), display
  blanks after 5s. The default `SUPER+CTRL+L` bind for this is unbound -
  only SHIFT+L is used.
- **`SUPER+SHIFT+S`** = screenshot (was `PRINT`, now unbound). Runs
  `omarchy-capture-screenshot smart copy` - **`copy` mode on purpose**:
  clipboard only, no file written to `~/Pictures` on every capture. Use
  `omarchy capture screenshot smart save` by hand when a file is actually
  wanted.
- **`SUPER+H`** = toggle workspace layout (the old `SUPER+L` action).
  Careful, this has a side effect - see the Workspaces section below.
- **`CTRL+SHIFT+ESCAPE`** = shutdown, **`SUPER+CTRL+SHIFT+R`** = reboot.
  Reboot deliberately is *not* on bare `CTRL+SHIFT+R` - that's hard-refresh
  in every browser and a global bind would shadow it everywhere.

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

**Which of these actually turns the panel off** - answered from the shell
log, because it is genuinely confusing from the outside:

| Trigger | What runs | Display |
|---|---|---|
| `SUPER+L` | `omarchy-lock-light` (sets the `noBlank` flag) | **stays on** |
| `SUPER+SHIFT+L` | `omarchy-system-lock` | off after 5s |
| 2 min idle | `ttfx` screensaver | stays on |
| **5 min idle** | `omarchy-system-lock` - a **full** lock | **off after 5s** |

The last row is the one that surprises. The idle auto-lock is *not* the
light lock; it blanks like `SUPER+SHIFT+L` does. So "I only pressed SUPER+L
and the screen went dark anyway" is almost always: SUPER+L, then walking
away, then something re-armed the idle cycle.

To check rather than guess:
`journalctl --user --since -3d | grep -E 'idleBlankTimer|lock-system'`.
`idleBlankTimer fired: ... noBlank=true` means the blank was **suppressed**
(light lock working as designed); `noBlank=false` means it went through.
Both appear in this machine's log, which is how the table above was
confirmed rather than assumed.

Locking is orthogonal to the display either way - see the "never affects
background processes" note above. If the 5-minute blank is unwanted, the
knobs are: raise `idle.lock` in `shell.json`, or change `lockSystem()` in
`gradiscp.idle/Service.qml` to call `omarchy-lock-light` instead of
`omarchy-system-lock`. The second one costs battery on a laptop, which is
why it was left alone.

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

**`SUPER+H` (toggle dwindle/master) writes a PER-WORKSPACE layout override**
to `~/.local/state/omarchy/workspace-layouts/<N>.lua`, which silently beats
the global `layout = "scrolling"` in `looknfeel.lua` for that workspace
only. Symptom: "scrolling isn't applying" / "this window is tiled wrong"
on some workspaces but not others, surviving reboots. Fix:
`rm ~/.local/state/omarchy/workspace-layouts/*.lua && hyprctl reload`.
This bit twice - check that directory first whenever layout behavior looks
inconsistent between workspaces.

### Scaling gotchas (both cost real debugging time)

- **Monitor scale resets to a stale value when external monitors are
  plugged in.** `monitors.lua` uses one catch-all `hl.monitor({ output =
  "" ... })` rule for every output, so a newly connected display can pull
  the whole config back to whatever value was last persisted. Always
  re-set it with `omarchy hyprland monitor scaling 1.25` (the CLI, which
  persists correctly) rather than hand-editing the file. Current intended
  value: **1.25**.
- **Firefox scaling is NOT controlled by the system scale if a `user.js`
  exists.** A `layout.css.devPixelsPerPx` entry in
  `~/.config/mozilla/firefox/<profile>/user.js` is re-applied on *every*
  launch and overwrites whatever is in `prefs.js`, so deleting the
  `prefs.js` line alone does nothing - the value comes back on restart.
  Firefox must be fully closed (`pkill firefox`) before editing either
  file, or it rewrites `prefs.js` on exit. Note the profile lives under
  `~/.config/mozilla/` here, not the usual `~/.mozilla/`.
  Currently: no `user.js`, no `devPixelsPerPx` - Firefox follows the
  system scale like everything else, which is what's wanted.

## Custom theme: `crimson-core`

Lives in `config/omarchy/themes/crimson-core/`, symlinked as a **whole
directory** to `~/.config/omarchy/themes/crimson-core` (not a per-file
overlay - it is its own theme, not a tweak of a stock one).
`omarchy-theme-list` globs both directories and symlinks, so linking the
directory is all that is needed.

Every color in `colors.toml` was sampled out of the wallpaper
(`backgrounds/0-3d-tech.jpg`) with `magick ... -colors N -unique-colors
txt:` rather than invented - the near-black void `#0e0d0c`, the red neon
strip `#e4212d`, and the brushed-steel grays `#7b837b` / `#8c948d` /
`#d9dddb` off the circuit board. The warm ANSI slots (red/orange/yellow/
magenta/brown) are the neon and its spill onto metal; the cool slots
(green/cyan/blue) are the steel, which is why "green" here is a gray-green
and there is no real blue - the image has none.

- `hyprland_active_border` is **one flat color** (`rgba(e4212dff)`), on
  purpose. A gradient was tried first
  (`rgba(e4212dee) rgba(7a1015ee) 45deg`, matching the render's own 45deg
  lighting) and rejected - on a real window it reads as an unevenly lit
  border, brighter at the top and muddy at the bottom, not as a design.
  With a single color `omarchy-theme-set-templates` emits a plain string
  instead of the Lua `{ colors = {...}, angle = N }` form; the shell reuses
  the same value for popup/notification/menu borders via the
  `hyprland.active-border` token, so they all stay in step.
- The `*_foreground` values and the cool ANSI slots are the raw steel
  samples **lifted one notch brighter** (e.g. `foreground` `#b5bbb8` ->
  `#cbd0ce`) - the literal sample was legible but dim against a near-black
  background. `bright_foreground` (`#edefee`) is pushed just past the
  brightest pixel actually in the image so bold/headings still separate.
- **No `shell.toml`, no `preview.png`, no `vscode.json` are shipped on
  purpose.** `shell.toml` *replaces* the generated file rather than merging
  into it, so shipping one means hand-maintaining ~200 lines that drift on
  every Omarchy update; the generated one already lands on solid `#0e0d0c`.
  `preview*.png`/`unlock.png` are referenced by nothing in
  `/usr/share/omarchy/{bin,shell}` (checked) - stock themes ship them, they
  are not required. `vscode.json` names an extension to install and VS Code
  isn't used here.
- `neovim.lua` uses `ficcdaf/ashen.nvim` (rust/red on near-black), which was
  **already installed** in `~/.local/share/nvim/lazy/` because the stock
  `solitude` theme declares it - so switching to this theme does not trigger
  a plugin download.
- Icons are `Yaru-red-dark`, keyboard LEDs `e4212d`.

To re-sample or retune: edit `colors.toml` in the repo, then
`omarchy theme set crimson-core` (the theme dir is a symlink, so a repo edit
is live immediately - but the *generated* files under
`~/.local/state/omarchy/current/theme/` are only rebuilt on `theme set`).

## Appearance settings and where they live

Scattered across several files, so listing them in one place:

| What | Where | Current value |
|---|---|---|
| Window layout | `hypr/looknfeel.lua` | `scrolling` (niri-like) |
| Scrolling column width | `hypr/looknfeel.lua` | `1.0` - 0.97 still left a visibly-not-full-screen margin |
| Window gaps | `hypr/looknfeel.lua` | `gaps_in = 3`, `gaps_out = 6` |
| Corner rounding | `hypr/looknfeel.lua` | `10` |
| Fullscreen opacity | `hypr/looknfeel.lua` | `0.9` - Hyprland forces 1.0 by default, ignoring per-window opacity rules |
| Cursor | `hypr/looknfeel.lua` + `gsettings.sh` | Bibata-Modern-Ice, size 14 (both places, they must agree) |
| Monitor scale | `hypr/monitors.lua` | `1.25` - set via CLI only, see Scaling gotchas |
| Terminal font | `foot/foot.ini` | JetBrainsMono Nerd Font size 8 |
| Terminal transparency | `foot/foot.ini` | `alpha=0.85` under `[colors-dark]`, NOT `[main]` |
| Font weight (global) | `fontconfig/conf.d/51-embolden-jetbrains.conf` | synthetic embolden - only Regular/Bold faces are installed, no Medium/SemiBold to switch to |
| Active theme | `omarchy/themes/crimson-core/` | `crimson-core` - custom, see the section above |
| Bar background | generated from `crimson-core/colors.toml` `background` | `#0e0d0c`, alpha `1.0` - no `shell.toml` overlay is shipped for this theme, so the generated one is used as-is |
| Bar transparency toggle | `omarchy/shell.json` `bar.transparent` | `false` - **double-clicking the bar's center toggles this**, which is why it seems to change on its own |
| Bar widgets | `omarchy/shell.json` `bar.layout` | center: clock (`ddd d MMM HH:mm`), keyboard-layout, system-update - **weather removed**; right: tray, agents, bluetooth, network, audio, monitor, power |
| Per-window opacity | `hypr/hyprland.lua` | foot `0.85/0.80`, Nautilus `0.85/0.75`, Firefox `0.80/0.70` |
| Idle screensaver / lock | `omarchy/shell.json` `idle` | 120s / 300s |

Firefox opacity has to target the **`firefox-based-browser` tag**, not the
`firefox` class - Omarchy's own `default/hypr/apps/browser.lua` forces
tagged windows back to opacity 1.0 and loads before user config, so a
class-based rule loses. Firefox's own New Tab page with a custom background
image still renders opaque regardless (the page declares itself opaque to
the GPU); that's a Firefox-side thing, not fixable from the compositor.

## Removed from the stock Omarchy app set

Real packages: `aether`, `cliamp`, `omacut`, `kdenlive`, `localsend`,
`moonlight-qt`, `obs-studio`, `pinta`, `xournalpp`, `chromium` (+ ~18
packages that became orphaned afterward, also removed). Webapp shortcuts
(just `.desktop` files, never real packages): Basecamp, HEY, Zoom, the 4
Google webapps, X/Twitter, plus Discord/WhatsApp/YouTube (removed later,
when they broke from Chromium being gone - see the webapp note above).

**All 22 stock themes were deleted too** (~119MB out of
`/usr/share/omarchy/themes/`), leaving only `crimson-core`. There is no
supported way to *hide* a theme - `omarchy-theme-list` globs
`$OMARCHY_PATH/themes` unconditionally and `omarchy theme remove` only
touches `~/.config/omarchy/themes` - so deletion is the only option, and
`NoExtract = usr/share/omarchy/themes/*` in `/etc/pacman.conf` (added under
`[options]`, with a timestamped `.bak` of the original next to it) is what
stops `omarchy update` from restoring them. Both are re-applied by
`remove-unwanted-apps.sh`. **To undo:** delete the `NoExtract` line, then
`sudo pacman -S omarchy`. Seeding "Tokyo Night" on a fresh install is
guarded by `theme.name` already being non-empty
(`/usr/share/omarchy/install/user/theme.sh`), so nothing re-seeds it here -
but a future Omarchy migration that assumes a stock theme exists is the one
real risk this trade accepted.

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
copy an SSH key into `~/.ssh`. `install.sh` ends with
`omarchy theme set crimson-core`, which is also what makes the theme's
generated files (foot/hyprland/shell colors) exist at all - a theme does
nothing just by sitting on disk. `remove-unwanted-apps.sh` also deletes the
stock themes and adds the pacman `NoExtract` line, so run it before being
surprised that `omarchy theme list` still shows 23 entries.
