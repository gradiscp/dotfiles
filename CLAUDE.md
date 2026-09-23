# dotfiles

Omarchy Linux config for a Samsung Galaxy Book Pro 360. This file is notes
for whoever (human or Claude) touches this repo next - the *why* behind
non-obvious choices, and known gotchas that cost real debugging time.

There is no `archive/` any more (the old EndeavourOS+KDE installer config was
dropped). **This machine was installed fresh with Omarchy on 2026-08-22** -
the pacman log starts with a clean base install, and no KDE/Plasma packages
exist - so nothing on it is a leftover from that earlier setup, SDDM
included (Omarchy requires it).

**The git history was rewritten twice (2026-08-23, 2026-08-28)** - first
to strip a committed `user_credentials.json` (login password hash; the repo
is public, so treat that hash as compromised and change the password) plus
some large files, then to put every commit under the GitHub noreply author.
Consequence for any old clone or fork: **re-clone, don't pull**. Unknown
commit hashes in an old note are this, nothing was lost.

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
- **Git identity: global config (`Paul Gradischnig` /
  `92756104+gradiscp@users.noreply.github.com`) is correct and
  intentional** - don't set a local `user.name`/`user.email` override in
  this repo, and don't "fix" the global one either. There is no local
  override right now, and there should not be one: that happened once
  during setup (an assistant used a different name/email from elsewhere in
  its context) and looked like the config "kept reverting" when it was
  actually the local override fighting the correct global value.
  `git log --format=%ae | sort -u` is the source of truth: one address.

## Session crash 2026-08-28 - Hyprland, not the lock screen

The "Oopsie daisy ... lockscreen app died" screen is the aftermath, not the
cause. `~/.cache/hyprland/hyprlandCrashReport*.txt` showed the real one: with
the panel **blanked** under a lock, a lid event triggered a DRM connector
rescan and Hyprland (v0.56.2, Aquamarine) segfaulted inside
`CDRMBackend::log()` - an upstream bug, nothing in this repo. The race needs
a blanked panel plus a lid/hotplug event: `SUPER+L` never blanks, so it
cannot get there; `SUPER+SHIFT+L` and the idle auto-lock (blanking again
since 2026-09-10, on request) can. Accepted knowingly.

To read the next one: `coredumpctl list`, `coredumpctl info <pid>`, and
above all the crash report file - its log tail says more than the
unsymbolized backtrace.

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
- **Omarchy's own tools turn the repo symlinks into plain files.** Confirmed
  in their source: `omarchy-shell-config` writes a temp file and `mv`s it
  over `~/.config/omarchy/shell.json`; `omarchy-hyprland-monitor-scaling`
  runs `sed -i` on `monitors.lua` without `--follow-symlinks`. Seen live
  2026-09-13: `omarchy theme set` also left `shell.json` as a plain file
  with `bar.transparent` flipped to `true` (the bar looked grey, not black)
  - run `omarchy-drift-check` after every `theme set`. Until
  2026-09-13 all six `hypr/*.lua`, `shell.json`, `foot.ini`, the lock/idle
  plugin dirs and more were plain copies, and **editing the repo file alone
  changed nothing live** - `hyprctl reload` reports success while running
  the old config, and a binding edited in the repo never showed in
  `hyprctl binds`. Now `bin/omarchy-drift-check` re-links any copy whose
  content still equals the repo and reports one that differs; it runs after
  every `omarchy update` (post-update hook) and by hand. So: after an
  `omarchy hyprland ...` / `omarchy bar ...` command, or when something
  "doesn't apply", run `omarchy-drift-check` first, then verify with
  `hyprctl binds` / `hyprctl configerrors` - never by assuming. If it
  reports a copy that *differs*, the live side usually holds a change made
  through Omarchy's UI: copy it into the repo, then re-run.
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
  of any *two-value* per-window `opacity` rule - Hyprland has a separate
  `decoration.fullscreen_opacity` setting for this, set in `looknfeel.lua`.
  **An `opacity` rule takes up to three values** (`active inactive
  fullscreen`; a fourth errors with `more than 3 alpha values`), **but each
  value is multiplied by the matching global one unless it is followed by
  `override`**. So `"0.80 0.70 1.0"` gave Firefox 1.0 x 0.9 in fullscreen -
  still see-through. Measured 2026-09-13 on a white fullscreen probe window:
  centre pixel 231 with `"1.0 1.0 1.0"`, 255 with
  `"1.0 override 1.0 override 1.0 override"`; `hyprctl getprop <win>
  opacity_fullscreen_override` shows which one applies. Until then this note
  claimed the plain three-value form was verified - only the parsing had
  been checked, never the pixels. `hyprctl getprop <win> opacity_fullscreen`
  reads `1` either way, so don't take that value as proof.
- **Hyprland title regexes must match the whole title.** `(?i)(prime video)`
  never matches `Prime Video: ... — Mozilla Firefox`; `(?i).*(prime video).*`
  does (tested 2026-09-13 with probe windows and `hyprctl eval`). The
  streaming-site rule in `hyprland.lua` had this bug from the day it was
  written. Title rules *are* re-applied when a title changes - also tested -
  so a tab navigating to a matching site is caught.
- **`omarchy-launch-webapp` hardcodes a Chromium-family browser.** It reads
  the default browser via `xdg-settings`, but only recognizes
  `google-chrome|brave|microsoft-edge|opera|vivaldi|helium` - anything else
  (including Firefox) falls through to `chromium.desktop`. **Chromium has
  been uninstalled here**, so every webapp shortcut that went through it
  (WhatsApp/Discord/YouTube) errored out with `Path "--app=..." does not
  exist!` - those three `.desktop` files were deleted rather than
  reinstalling Chromium. **`Docker.desktop` was deliberately kept**: it
  runs `lazydocker` in a terminal, never touches `omarchy-launch-webapp`,
  so it was never affected - and since 2026-09-21 it lives in
  `config/applications/` and is linked by `install.sh`, so a fresh install
  has it. The `claude-cli://` handler `mimeapps.list` names is *not* in the
  repo: Claude Code writes it itself with an absolute path. If a webapp shortcut is ever wanted again,
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

- **The Omarchy menu is on the stock `SUPER+SPACE`, and only there.** This
  went back and forth: `SUPER+SPACE` was unbound in favour of a bare Super
  tap (`SUPER + SUPER_L` with `{ release = true }`), then both worked, and
  now the bare tap is gone again and `SUPER+SPACE` is the only way. A
  release-bind on the modifier itself fires on *every* Super tap that didn't
  run another bind - including pressing Super and changing your mind - which
  is what got it dropped. Don't re-add it without asking.
- **`SUPER+L`** = "light" lock via `~/.local/bin/omarchy-lock-light`:
  real password-gated session lock, display **never blanks**. The script
  only drops the `noBlank` flag and then `exec`s the stock
  `omarchy-system-lock` (until 2026-09-21 it carried a hand-copied duplicate
  of that script's body). Was previously "Toggle workspace layout"
  (dwindle/master) - moved to `SUPER+H`.
- **`SUPER+SHIFT+L`** = full lock (`omarchy-system-lock`, stock): the
  normal Omarchy lock screen plus a clock (`FullLockView`, see the lock
  screen section), display blanks after 5s. The idle auto-lock takes this
  same lock. The default `SUPER+CTRL+L` bind for this is unbound - only
  SHIFT+L is used.
- **`SUPER+SHIFT+S`** = screenshot (was `PRINT`, now unbound). Runs
  `omarchy-capture-screenshot smart copy` - **`copy` mode on purpose**:
  clipboard only, no file written to `~/Pictures` on every capture. Use
  `omarchy capture screenshot smart save` by hand when a file is actually
  wanted.
- **`SUPER+P`** = jump to the Claude session waiting for a permission
  (`claude-notify jump`, see the Claude permission toasts section).
  Was "Pseudo window", a dwindle-only action that does nothing in the
  scrolling layout. **Fn+Enter was asked for first and can't work**: Fn is
  resolved inside the keyboard, so Linux only ever sees a plain Enter.
- **`SUPER+W`** = close window, **but asks first for a terminal with
  something still running** (`bin/window-close-guard`). "Running" means the
  terminal's shell has a child process - Claude, herdr, ssh, an editor. An
  idle prompt, a terminal started straight into a TUI, and every
  non-terminal window close at once as stock (GUI apps with unsaved work ask
  on their own). The question is our own overlay plugin,
  `config/omarchy/plugins/gradiscp.closeconfirm/`, summoned as
  `omarchy-shell shell summon gradiscp.closeconfirm '{"process":"claude"}'`.
  It draws a **slim strip under the bar**: terminal glyph, "<process>
  läuft noch. Schließen?", then the two buttons - no dimmed backdrop, and
  translucent like a toast, because it takes its colors from the
  `Color.notifications.*` tokens, whose background already carries the
  theme's 0.85 alpha. `hyprland.lua` blurs the `gradiscp-closeconfirm`
  layer for it, exactly like `omarchy-notifications`. The surface still
  covers the whole screen (transparent) to hold the exclusive keyboard
  focus. Keys: **Tab /
  Shift+Tab / Left / Right** switch, Enter picks, Escape or a click beside
  the strip cancels. **"Abbrechen" is preselected on purpose**, so a stray
  Enter keeps the window - and hover only moves the selection after the
  pointer really moved (stock `PointerMoveGate`; a synthetic hover on the
  strip appearing under a resting cursor would otherwise preselect
  "Schließen", 2026-09-21); **SUPER+W a
  second time confirms** - through `window-close-guard` when Hyprland's bind
  fires, and through the dialog's own key handler if the key reaches the
  dialog instead. Neither path can be exercised with `wtype`: a synthetic
  `wtype -M logo -k w` triggered no bind and reached no surface (plain keys
  like Tab did reach the dialog), so SUPER+W needs a real keyboard to test.
  The bind runs via `hl.dsp.exec_cmd` with Hyprland's PATH, which includes
  `~/.local/bin` - the same route `SUPER+L`'s `omarchy-lock-light` takes.
  The window being
  asked about is held in `$XDG_RUNTIME_DIR/window-close-guard/pending` and
  ignored after a minute, so an abandoned question can't close anything
  later. Like every overlay/service plugin, edits need
  `omarchy restart shell`.
  **Not an Omarchy menu route** (tried first): the stock menu has no Tab
  handling (`Menu.qml` only knows Up/Down/PageUp/PageDown), and adding it
  would mean owning a clone of the ~1200-line menu.
  Note that closing herdr's window only detaches: its server keeps every
  pane (and every Claude in it) running, `SUPER+CTRL+RETURN` reattaches.
- **`SUPER+H`** = toggle workspace layout (the old `SUPER+L` action).
  Careful, this has a side effect - see the Workspaces section below.
- **`CTRL+SHIFT+ESCAPE`** = shutdown, **`SUPER+CTRL+SHIFT+R`** = reboot.
  Reboot deliberately is *not* on bare `CTRL+SHIFT+R` - that's hard-refresh
  in every browser and a global bind would shadow it everywhere. Stock has
  "Clear reminders" on the same chord and Hyprland runs *every* matching
  bind, so it is unbound first - spelled `SUPER + SHIFT + CTRL + R` like
  stock, because `hl.unbind` matches the string as written (2026-09-21).

### Unbound defaults (dead keys)

`bindings.lua` unbinds 15 stock bindings whose target isn't on this machine.
Verified 2026-08-28 with `command -v`; **re-check before re-adding any**:

- **Missing apps:** Spotify (`SUPER+SHIFT+M`), cliamp (`SUPER+SHIFT+ALT+M`),
  Signal (`SUPER+SHIFT+G`), 1Password (`SUPER+SHIFT+SLASH`). The
  `omarchy-launch-*` scripts for these still exist, so nothing errors - the
  key just silently does nothing, which is why they were easy to miss.
- **All 11 webapp binds** (ChatGPT, Grok, HEY calendar/email/new-email,
  YouTube, WhatsApp, Google Messages, Google Photos, X, X post). Same root
  cause as the deleted `.desktop` files: `omarchy-launch-webapp` falls back
  to `chromium.desktop` for any non-Chromium-family default browser, and
  Chromium is uninstalled here. These are the keyboard half of that problem.
- `SUPER+SHIFT+S` (Google Maps) is *not* in that list - it was already
  unbound and reused for the screenshot bind.

Still bound and working: Obsidian `SUPER+SHIFT+O`, Omawrite `SUPER+SHIFT+W`,
Herdr `SUPER+CTRL+RETURN`, Docker/lazydocker `SUPER+SHIFT+D`, tmux
`SUPER+ALT+RETURN`. Note `SUPER+CTRL+ALT+D` ("Calendar") is the shell's own
clock popup, not the HEY webapp - it works, leave it.

Setting `omarchy_preinstalled_bindings = false` would have killed all of
these in one line, but it would also have killed the five working ones
above, hence the explicit `hl.unbind` list.

### Lock screen design (`config/omarchy/plugins/gradiscp.lock/`)

A clone of the `omarchy.lock` service plugin with **two views**, picked per
lock by the `noBlank` flag (see below):

- **`FullLockView.qml`** - for `SUPER+SHIFT+L` and the idle auto-lock
  (added 2026-09-10). The stock `omarchy.lock` view, reworked:
  - the *theme wallpaper* **sharp** - stock's blur `MultiEffect` is gone;
  - an `HH:mm` clock with a `dddd, d MMMM` date in the **bottom-left
    corner** (same `SystemClock` the bar clock uses; **stock has no clock
    at all**), with a drop shadow, which is what keeps it legible now that
    nothing is blurred;
  - the password field has a **transparent fill and starts invisible**.
    Any keystroke or click fades/scales/slides it in (240ms in, 420ms out,
    `OutCubic`); it hides again 3s after the last keystroke, but never
    while there is text in it or a password check is running. A wrong
    password re-reveals it so the error is readable. It stays focused at
    opacity 0 - opacity doesn't affect focus, the minimal `LockView`
    already relied on the same thing - so the first key both types and
    reveals.
  - **clock and field never share the screen**: while the field is shown
    the clock fades and sinks out, with the same timings mirrored, and
    comes back when the field hides. Both hang off one `fieldShown`
    binding, so they cannot get out of step.
  - **the keystroke that wakes the blanked panel only wakes it** (added
    2026-09-20 on request: "erst die Uhr und nicht direkt das Passwortfeld").
    `Service.qml` tracks the panel state in `displayBlanked` (set in
    `runBlank()`, cleared in `runWake()`); `FullLockView`'s `wakeFromBlank()`
    reads that flag *before* emitting `wakeRequested`, because the wake
    clears it in the same call. When it was set, the key is swallowed
    (`event.accepted = true`, so `TextInput` inserts nothing and
    `onTextChanged` cannot pull the field up behind it) - you get the clock,
    and only the next key starts the password. Same for a click. The
    5s blank timer is unchanged and re-arms on the wake, so an untouched
    lock goes dark again 5s after you looked at the clock.

  The password logic itself (dots, `Checking…`, error text, fingerprint
  hint) is stock and unchanged; if this is ever re-synced from a newer
  `omarchy.lock`, the list above is what to carry over. It unlocks straight
  away on success (no icon, so no flash). It is also what
  `omarchy-shell lock preview` shows - the one way to look at it without
  locking, though only in its idle clock-only state, since the preview
  takes no input (`omarchy-shell lock hidePreview` or a click closes it).
- **`LockView.qml`** - for `SUPER+L` only, deliberately minimal. Everything
  below about the screenshot, the icon and blind typing is this view.
  Since 2026-09-20 it also carries the light lock's **own screensaver**
  (`MatrixRain.qml`): after **3 min** without input (`screensaverDelay`, a
  plain constant in `LockView.qml` - not `idle.screensaver` from
  `shell.json`, which belongs to the desktop) the screenshot and the icon
  fade out behind black and a matrix rain starts; any key or mouse movement
  ends it and restarts the three minutes, and the key that ends it is
  swallowed, exactly like the real screensaver's first keystroke. **"Mouse
  movement" means the pointer travelled more than 3px from where the
  `MouseArea` last saw it** (`pointerMoved()`), not `positionChanged` as
  such: Qt Quick delivers a hover event at the unchanged cursor position
  whenever the scene under the cursor changes, and the rain fading in is
  such a change - the first version was dismissed by exactly one such
  synthetic event a second after it appeared ("geht nach kurzer Zeit wieder
  aus"), reproduced with a `console.log` in `dismissScreensaver()`, which is
  still there: `journalctl --user | grep 'screensaver dismissed'` names the
  cause of every dismiss. The columns themselves never restart as a whole:
  each one loops on its own random period, so the rain is continuous until
  something dismisses it. The panel
  is never blanked, so this stays out of the DRM crash's blanked-panel
  state. **The real Omarchy screensaver cannot be used here**: it is
  `ttfx --random-effect` in a foot window (`omarchy-launch-screensaver`),
  i.e. an ordinary Hyprland window, and a session lock renders nothing but
  its own surface - which is why `gradiscp.idle` guards it with
  `omarchy-shell lock isLocked` and `omarchy-lock-light` kills ttfx before
  locking. So of ttfx's ~40 effects only `matrix` was rebuilt in QML; don't
  go looking for a way to show the real one over the lock.

  **Every per-column value in `MatrixRain.qml` is rolled once, at creation,
  and never touched again while the column falls** - length, speed, gap and
  the random first-fall offset that keeps the columns from starting as one
  synchronized wave. Only the glyphs change, from one 140ms timer. The first
  cut re-rolled all of it from a `ScriptAction` inside the falling
  animation: assigning to a running animation's properties restarts that
  animation, which ran the `ScriptAction` again, until the QML engine threw
  `RangeError: Maximum call stack size exceeded` and the whole shell hung -
  with the full-screen preview overlay (exclusive keyboard focus) stuck on
  screen and no way to type past it. `pkill -f quickshell` is the way out;
  `omarchy-launch-shell` respawns it. Before that the durations were plain
  bindings, which QML reported as binding loops for the same reason. Also:
  the trail is `Text.StyledText` markup, so `<`, `>` and `&` must stay out
  of the glyph set or they are parsed instead of drawn (they showed up as
  literal `</font><br>` runs in the rain).

Both sit inside the session lock surface; only the visible one gets
`inputEnabled`, so they never compete for keyboard focus. `noBlank`
resolves ~1ms after `lock-requested` and the surface comes up ~500ms later
(read off the journal), so the wrong view is never actually on screen.

- **Background is a live screenshot of the desktop at the moment of
  locking** (`grim`, started from `noBlankCheckProc` once the lock is known
  to be a light one - the full view has no use for it - still long before
  the session-lock surface takes over rendering; can't screenshot after
  that point, app content is no longer composited), lightly blurred - not
  the static theme wallpaper Omarchy uses by default.
- **That capture is asynchronous, and used to race the lock surface.** grim
  runs as a `Process`; the lock surface (and with it `LockView`'s `Image`)
  could come up first and point at a path that was either absent (first lock
  after boot) or half-overwritten (grim wrote the PNG in place). Every lock
  logged `Error decoding: .../omarchy-lock-screenshot.png: Unable to read
  image data`, then self-healed when `screenshotVersion` bumped on grim's
  exit and forced a reload. Fixed 2026-08-28 two ways: a `screenshotReady`
  flag gates `loadBackground`, so the Image gets no source until grim has
  succeeded *for that lock*; and grim now writes `<path>.tmp` and `mv`s it
  into place, so a reader sees the old file or the new one, never a partial
  one. If grim fails, `screenshotReady` stays false and the lock screen
  keeps its flat background - a better failure than a broken Image.
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
  unlock) does two jobs for SUPER+L specifically: it suppresses the
  plugin's own 5-second post-lock display-blank timer, and it selects
  `LockView` over `FullLockView`.
- **Dead end, don't repeat:** a passwordless "privacy cover" panel
  (`gradiscp.privacycover`, deleted from disk 2026-08-28 - it had been
  merely disabled, still sitting in `~/.config/omarchy/plugins/` but absent
  from `shell.json`'s `plugins` list) was built first,
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

Clone of `omarchy.idle`. The one lasting change is in `lockSystem()`: it
checks `omarchy-shell lock isLocked` before locking - without this, going
idle while already locked fires a second lock call. Mirrors the guard the
stock screensaver path already had. It matters more now that the idle lock
blanks: a session locked with `SUPER+L` stays exactly as it is (lit,
minimal view) however long it then sits idle.

**History of the lock command - it has flipped twice, check before
touching it.** Stock is `omarchy-system-lock`. On 2026-08-28 it became
`omarchy-lock-light` (lock for real, never blank the panel), because "I only
pressed SUPER+L and the screen went dark anyway" turned out to be SUPER+L,
walking away, and the idle cycle blanking it - and to stay out of the DRM
crash's blanked-panel state. **On 2026-09-10 it went back to
`omarchy-system-lock` on explicit request** ("nach 1 min Screensaver, nach 3
Bildschirm aus"): the idle lock now shows the full lock screen with the
clock and turns the panel off 5s later, same as `SUPER+SHIFT+L`. That brings
the crash exposure back (see above); the `isLocked` guard is what keeps the
old SUPER+L complaint from returning. The `shell.idleConfig` fallback on
`idleConfig` was synced from the updated stock plugin at the same time.

**Watching a film/series no longer trips the screensaver** (added
2026-09-04). `bin/omarchy-idle-audio-guard` + the systemd user unit
`config/systemd/user/omarchy-idle-audio-guard.service` poll PipeWire every
15s and hold Omarchy's own stay-awake flag
(`~/.local/state/omarchy/indicators/stay-awake`, the same one
`omarchy toggle idle` and the bar indicator use) while any sink reports
`RUNNING` **and a window is in real fullscreen on a workspace that is on
screen**. Sink-level detection means it covers speakers, the headphone
jack, Bluetooth and HDMI alike, and every app, not just the browser.

**The fullscreen half was added 2026-09-20.** Until then audio alone held
the flag, and Firefox playing music to the JBL Flip 3 kept the laptop from
ever locking - reported as "geht nicht mehr gelockt", and the idle log
(`journalctl --user | grep 'omarchy idle'`) showed nothing but
`stay-awake: enabled state-file` / `idle-cycle-cancel: stay-awake` all
afternoon, with `stay-awake-by-audio` next to the flag. **So when the
machine "never locks", check `ls ~/.local/state/omarchy/indicators/` and
`omarchy-shell idle status` (`enabled:false, stayAwake:true`) before
suspecting the idle or lock plugins.** Fullscreen means `hyprctl clients -j`
`.fullscreen == 2` (SUPER+F, or a video that went fullscreen by itself);
`1` is maximized (SUPER+ALT+F) and does not count - probed on Hyprland
0.56.2 with a foot window, see the comment in the script. Music, or a video
in a normal tab, now locks after the idle time like anything else; if that
is ever wanted awake, `omarchy toggle idle` by hand is the way (the guard
respects it, see below).

**Why a homegrown guard and not Firefox's own inhibit:** Firefox *has* a
Wayland idle-inhibit backend (`WaylandIdleInhibit`, since Firefox 74,
bugzilla 1587360; `strings libxul.so` on the installed 155 shows
`InhibitWaylandIdle`), but it never reaches it here. `WakeLockListener.cpp`
tries the backends in a fixed order and only moves on after a *fatal*
failure; the xdg-desktop-portal `Inhibit` call "succeeds" against
xdg-desktop-portal-gtk, which has no session manager behind it, so Firefox
stops there and nothing is inhibited. Omarchy's idle plugin
(`IdleMonitor { respectInhibitors: true }`) honours only Wayland inhibitors.
**Until 2026-09-21 this file claimed Firefox had no Wayland path at all -
that was wrong** (found in the audit that day, upstream Omarchy PR #7877
has the same analysis). The env `MOZ_WAKE_LOCK_TYPE=WaylandIdleInhibit`
would make Firefox skip straight to the Wayland backend and the guard could
go - **deliberately not done**: that inhibits for *any* audio, which is the
music-in-a-tab behaviour the fullscreen rule was added to get rid of, and
upstream notes the inhibitor can stick when playback starts unfocused.
Unverified live here.

Manual toggles win over the guard: it never touches a flag it did not set
(marker file `stay-awake-by-audio` next to it), and if stay-awake is turned
off by hand mid-playback it stands down until playback restarts. The unit's
`ExecStop` releases the flag, so a logout can't leave the machine pinned
awake. To watch it: `journalctl --user -u omarchy-idle-audio-guard -f`.

`idle.screensaver` in `shell.json` is 120s (2 min) - triggers Omarchy's
built-in `ttfx`-based terminal screensaver, unrelated to the lock screen
above. `idle.lock` is 180s (3 min). History: 120s / 300s stock, 60s / 180s
from 2026-09-10, 240s / 300s from 2026-09-12, 120s / 180s from 2026-09-20
("nach 3 min nichts machen soll gelockt werden"). The lock has to stay *after*
the screensaver, or the screensaver is never seen - the lock blanks the
panel 5s later.
Both count from the moment idle began, not from each other.

**Which of these actually turns the panel off** - answered from the shell
log, because it is genuinely confusing from the outside:

| Trigger | What runs | Lock view | Display |
|---|---|---|---|
| `SUPER+L` | `omarchy-lock-light` (sets the `noBlank` flag) | minimal (`LockView`) | **stays on** |
| 3 min in that lock | `MatrixRain.qml`, drawn inside the lock surface | minimal + rain | **stays on** |
| `SUPER+SHIFT+L` | `omarchy-system-lock` | full, with clock | off after 5s |
| 2 min idle | `ttfx` screensaver | - | stays on |
| 3 min idle | `omarchy-system-lock` (skipped if already locked) | full, with clock | off after 5s |

Between 2026-08-28 and 2026-09-10 the last row was `omarchy-lock-light` /
**stays on**, and only `SUPER+SHIFT+L` blanked. If a non-blanking idle lock
is wanted again, that is the one command to swap back in
`gradiscp.idle/Service.qml`.

To check rather than guess:
`journalctl --user --since -3d | grep -E 'idleBlankTimer|lock-system'`.
`idleBlankTimer fired: ... noBlank=true` means the blank was **suppressed**
(light lock working as designed); `noBlank=false` means it went through.
Both appear in this machine's log, which is how the table above was
confirmed rather than assumed.

Locking is orthogonal to the display either way - see the "never affects
background processes" note above. The remaining knob is `idle.lock` in
`shell.json` (how long until it locks at all), currently 180s.

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

Workspaces 6-8 are marked `persistent` in `bindings.lua` so they always
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

## Claude permission toasts (herdr and plain terminals)

`bin/claude-notify`, hooked into Claude Code through
`config/claude/settings.json` (a `Notification` hook with matcher
`permission_prompt`). When a Claude session stops to ask for permission, an
Omarchy toast shows top right - the same `omarchy-notification-send -u
critical` popup as the low-battery warning. Clicking it (the toast's
`--exec`) goes straight back to that terminal:

- **Inside herdr** the hook inherits `HERDR_PANE_ID` from the pane Claude
  runs in; the click runs `herdr agent focus <pane>` and focuses herdr's
  window, found by walking the herdr *client's* parents up to a Hyprland
  window (the server's chain ends at systemd and never has one).
- **In a plain terminal window** (foot etc.) the hook walks up its *own*
  parents to the window that owns it, and the click focuses that window.
- **No toast** for Claude over SSH (the hook runs on the remote machine) or
  inside tmux (the tmux server belongs to no window) - nothing local to go to.

Details:

- **Gone after 10s no matter what**, or sooner once it has been dealt with:
  in herdr when the agent leaves `blocked`, in a plain terminal when that
  window gets focus (outside herdr there is no agent state to wait on). Omarchy's notification service
  never expires a *critical* toast (`durationFor` returns 0 for Critical and
  ignores `-t`), so a detached watcher takes it down with
  `omarchy-shell notifications dismiss <headline>`. `-u normal -t 10000`
  would expire by itself but loses the battery-warning look.
- The watcher waits for `blocked` **first**. herdr reads agent state off the
  terminal (detection worked even before the herdr Claude integration was
  installed on 2026-09-13) - so right when the hook fires it can still
  say `working`; waiting straight for "not blocked" would dismiss instantly.
- **No toast when you are already looking**: skipped when that pane is
  herdr-focused *and* herdr's window is the active Hyprland window, or for
  a plain terminal when its window is the active one.
- Because the toast vanishes, the keybind (**`SUPER+P`**) runs
  `claude-notify jump` - the most recent `blocked` herdr agent (by
  `state_change_seq`), else the last plain terminal that asked and has not
  been focused since (`$XDG_RUNTIME_DIR/claude-notify/last-window`). herdr
  wins when both are waiting, since it offers no timestamp to compare. That
  is used rather than the stock
  `SUPER+ALT+COMMA` "invoke last notification", which only reaches a toast
  that is still on screen.
- **Running Claude sessions keep the hook command they last loaded.** The
  first version was added by editing `~/.claude/settings.json` in place, and
  sessions already running picked that up. But when the script was renamed
  (`claude-herdr-notify` -> `claude-notify`) and the path in the repo file
  changed with `sed -i`, running sessions kept calling the old, deleted path
  and failed silently - and re-creating the `~/.claude/settings.json`
  symlink afterwards did **not** make them reload either (logged: the old
  path was still called after it). Only a restarted session reads the new
  command. So after changing the hook command, restart the Claude sessions,
  or leave something executable at the old path until they are.
- Every hook run logs its decision (`toast`, `skip: already looking`,
  `skip: no local terminal window`) to `$XDG_RUNTIME_DIR/claude-notify/log`
  - check it first when a toast "doesn't come"; a hook that never ran and
  a toast that was deliberately skipped look identical from the outside.

**`~/.claude/settings.json` is a symlink into this repo.** Claude Code writes
that file itself (`/model`, `/config`, permission "always allow" answers), so
expect the same story as `shell.json`: if `ls -la ~/.claude/settings.json`
ever shows a plain file, copy it back into `config/claude/` and relink.

**`tui` is deliberately unset - no fullscreen renderer** (removed
2026-09-12). `"tui": "fullscreen"` puts Claude Code on the terminal's
alternate screen, and herdr corrupts an alternate-screen pane whenever the
pane is resized ([herdr#3329](https://github.com/herdrdev/herdr/issues/3329),
open). On a `dwindle` workspace - workspaces 1-5 all had a `SUPER+H`
override until 2026-09-13, when the five files were deleted on request, see
the Workspaces section - Hyprland resizes the herdr window every
time another window opens or closes beside it, so every Claude pane in herdr
ended up as overlapping
garbage that Ctrl+L does not repair (`/exit` + `claude --resume` does). Don't
turn it back on until that issue is closed. Change renderer settings between
sessions, not under running ones: right after this edit, a session in a
plain foot window broke as well (cause not confirmed). Full write-up:
`2026-09-12-herdr-claude-fullscreen-garbled.md` in the `incidents` repo.

**`~/.claude/rules/` is a symlink to `config/claude/rules/` - the whole
directory** (added 2026-09-12). Every `.md` in it is a user-level rule that
Claude Code loads in *every* project at session start and re-injects after
`/compact`; one topic per file, so dropping a rule means deleting its file.
`ask-first.md` (rule file names are English, their content may be German)
makes Claude check what it can look up itself, then ask instead of guessing, and never invent file names/flags/API behaviour.
`incidents.md` (2026-09-13) points Claude at the postmortems in
`~/Projects/paulgradischnig/incidents`: read only the README index at the
start of a task and open matching incidents, search the repo for the symptom
before debugging an error, and *offer* a new postmortem after a real fix
(written only on a yes). Index-only on purpose, so the rule stays cheap as the
repo grows. `git-remote.md` (2026-09-13) tells Claude it cannot push, pull or
fetch - the SSH key has a passphrase, no ssh-agent runs, `gh` is logged out -
so it names what to push instead and never works around it (no HTTPS remote,
no token hunting).
Chosen over `~/.claude/CLAUDE.md` (same loading, but one growing file) and
over a skill (skills only load when Claude decides they fit - a rule about
not guessing has to apply exactly when it doesn't notice it is guessing).
**Keep `paths:` frontmatter out of these files** - with it a rule only loads
when Claude reads a matching file, and drops out after compaction. Claude
Code never writes into `rules/`, so unlike `settings.json` the link should
stay a link. Check it loaded with `/context` -> "Memory files" in a *new*
session; running sessions don't pick it up. The repo is public, so nothing
private goes in there.

## Bar and notification clones (2026-09-13)

All three live in `config/omarchy/plugins/`, are directory-symlinked into
`~/.config/omarchy/plugins/` by `install.sh`, and `shell.json` points the bar
and the plugin list at them.

- **`gradiscp.workspaces`** (`omarchy plugin clone omarchy.workspaces`): a dot
  per workspace instead of numbers - focused a red capsule (`bar.urgent`),
  occupied a filled dot, empty a hollow ring (numbers on or under the dots
  were tried and dropped). **`text` stays set on the
  `WidgetButton` even though `labelVisible` is false** - it renders itself at
  opacity 0 when `text` is empty. The clone keeps `moduleName: "omarchy.workspaces"` on purpose -
  `omarchy-plugin-clone` leaves built-in ids as IPC targets and routes them
  through `clonedFrom`.
- **`gradiscp.claude-status`** (new bar widget, right section between tray and
  agents): polls `claude-notify count` every 5s - herdr agents in `blocked`
  plus the last plain terminal that asked and was not visited, so plain
  terminals add at most 1. Terminal glyph U+F489, dim at 0, red with a count
  badge otherwise; a click runs `claude-notify jump`. It polls because herdr
  has no push event for agent state. The stock `omarchy.agents` widget only
  shows usage/limits, not session state.
- **`gradiscp.notifications`** (`omarchy plugin clone omarchy.notifications`):
  only `components/NotificationCard.qml` differs. Red border, and a red glyph
  on a dark-red tile, for critical toasts only - everything else gets a steel
  border (stock put the same red border on every toast, so nothing stood out).
  Text uses the injected monospace `fontFamily` instead of hardcoded Liberation
  Sans. Toasts from app `Claude Code` add "Klicken springt zum Terminal".
  Compact: 320 wide (stock 380), 30px glyph slot, 12px type, tighter padding.
  Service plugin, so edits need `omarchy restart shell`. The stock card already
  had a glyph slot (`-g`); despite the `countdown` color token there is no
  countdown bar.
- **Translucent toasts:** `config/omarchy/themes/crimson-core/shell.notifications.toml`
  sets `background-alpha = 0.85`, applied by `omarchy theme set crimson-core`.
  **It replaces the whole `[notifications]` section** of the generated
  `shell.toml` - `apply_shell_section_override` in
  `omarchy-theme-set-templates` drops the original section and emits the file's
  body - so every key of that section is repeated in the file; one holding only
  `background-alpha` would silently drop `border`, `text` and `countdown`.
  `hyprland.lua` blurs the `omarchy-notifications` layer, like the bar.

Verified live with screenshots: the pill on the focused workspace, the badge
with a forced count of 2, critical vs normal toasts, translucency with blur,
the compact size; no QML warnings from the three plugins after
`omarchy restart shell`. Not exercised: clicking the widget or a redesigned
toast (`wtype` can't click).

**Own skills live in `config/claude/skills/<name>/`**, linked one directory
each into `~/.claude/skills/` (2026-09-13). `docu-guard` is the end-of-session
documentation pass: it collects what the session changed from git and the
conversation, finds the project's own documentation (guideline, Obsidian
vault, docs/, README, CLAUDE.md/AGENTS.md, handoffs), routes each item to
exactly one place following that project's own documentation guideline,
and commits - so `/clear` loses nothing. Skills
are the right form here, unlike the rules: this should run when asked, not
in every turn. The AI setup stays in this repo rather than its own: nothing
in it is private, and a second repo would need its own install and drift
handling. Split out a private `ai-setup` repo only for things that must not
be public (e.g. `~/.claude/agents/`, which name private projects).

## Custom theme: `crimson-core`

Lives in `config/omarchy/themes/crimson-core/`, symlinked as a **whole
directory** to `~/.config/omarchy/themes/crimson-core` (not a per-file
overlay - it is its own theme, not a tweak of a stock one).
`omarchy-theme-list` globs both directories and symlinks, so linking the
directory is all that is needed.

**That symlink was found dangling on 2026-08-29** - it pointed at
`/home/gradiscp/Projects/dotfiles/...`, but the repo actually lives at
`/home/gradiscp/Projects/paulgradischnig/dotfiles/...`. Repointed with
`ln -sfn`. This is nastier than it sounds, because **nothing visibly
broke**: the desktop still looked themed, since the *generated* files under
`~/.local/state/omarchy/current/theme/` had been built while the path was
still valid and are what the shell/foot/hyprland actually read.
`omarchy-theme-list` also still printed "Crimson Core" (it globs symlinks
without resolving them). What gave it away was `omarchy-theme-dir
crimson-core` falling through to `/usr/share/omarchy/themes/crimson-core`,
a directory that does not exist (all stock themes were deleted). So: if a
theme-dir-reading command behaves oddly, **check `ls -laL
~/.config/omarchy/themes/` before anything else** - `omarchy theme set`
would have failed here too, and the live desktop is not evidence that the
link is intact. `install.sh` recreates it, but it had never run on this
machine (same story as the `hypr/*.lua` copies above).

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
  `preview.png` is referenced by nothing in `/usr/share/omarchy/{bin,shell}`
  - stock themes ship it, it is not required. `vscode.json` names an
  extension to install and VS Code isn't used here.
- `neovim.lua` uses `ficcdaf/ashen.nvim` (rust/red on near-black), which was
  **already installed** in `~/.local/share/nvim/lazy/` because the stock
  `solitude` theme declares it - so switching to this theme does not trigger
  a plugin download.
- Icons are `Yaru-red-dark` (`icons.theme`). No `keyboard.rgb`: it is read
  only by the QMK/ASUS keyboard-LED setters, which this laptop has no use for.

To re-sample or retune: edit `colors.toml` in the repo, then
`omarchy theme set crimson-core` (the theme dir is a symlink, so a repo edit
is live immediately - but the *generated* files under
`~/.local/state/omarchy/current/theme/` are only rebuilt on `theme set`).

**Backgrounds** live in `backgrounds/` and are numbered in cycle order
(`0-3d-tech.jpg` - the palette source - and `1-snowcapped-mountains.jpg`,
added 2026-09-13: red foliage, snow and near-black sky, same palette).
`omarchy theme bg next` / `SUPER+CTRL+SPACE` cycles them, the lock screen
follows the current one. **A new file in the repo is not seen until
`omarchy theme set crimson-core`**: `current/theme/` is a copy made at theme
set, not a link, so `bg next` cycled through the old single image until the
theme was re-applied.

## Boot / login screen: stock Omarchy, on purpose

The screen after powering on is the **Plymouth passphrase prompt for the
LUKS root**; SDDM autologins (`/etc/sddm.conf.d/autologin.conf`), so its
greeter only appears after a logout.

**The crimson-core restyle of both was dropped on 2026-09-21.** From
2026-08-29 the theme shipped `unlock.png` / `preview-unlock.png` and
`omarchy plymouth set by theme crimson-core` wrote them into
`/usr/share/{plymouth,sddm}/themes/omarchy/`, and `omarchy-drift-check`
re-applied it after every update (package updates of `omarchy-settings`
reset it each time). But on a real restart the owner still saw the Samsung
logo, not the wordmark ("es ist trotzdem Samsung") - `omarchy plymouth
current` reported `crimson-core` and the kernel line has `quiet splash`, so
the files were in place; why the firmware logo is what shows was **not
investigated** (unverified guess: the firmware/BGRT logo stays up for most
of the boot and the prompt is short). Not worth an initramfs rebuild per
update for something that is not seen. The installed files stay until the
next `omarchy-settings` update overwrites them, or `omarchy plymouth reset`
(sudo, rebuilds the initramfs) by hand.

**What must stay: never protect those theme directories with `NoExtract`.**
Tried 2026-09-13: pacman skips extracting the new copies but still removes
the old ones, so the 4.0.4 upgrade left both directories empty - a bare-text
LUKS prompt and a black screen after logout (`sddm: Loaded empty theme
configuration`). Recovery: drop the rule from `/etc/pacman.conf`,
`sudo pacman -S omarchy-settings`. `remove-unwanted-apps.sh` deletes the rule
if present and `omarchy-drift-check` reports it.

## Appearance settings and where they live

Scattered across several files, so listing them in one place:

| What | Where | Current value |
|---|---|---|
| Window layout | `hypr/looknfeel.lua` | `scrolling` (niri-like) |
| Scrolling column width | `hypr/looknfeel.lua` | `1.0` - 0.97 still left a visibly-not-full-screen margin |
| Window gaps | `hypr/looknfeel.lua` | `gaps_in = 2`, `gaps_out = 3` - down from 3/6 on 2026-09-16 (stock 5/10); `border_size = 2` after 1 read as too thin |
| Corner rounding | `hypr/looknfeel.lua` | `10` |
| Fullscreen opacity | `hypr/looknfeel.lua` | `0.9` - Hyprland forces 1.0 by default, ignoring per-window opacity rules |
| Cursor | `hypr/looknfeel.lua` + `install.sh` (gsettings) + `config/sddm/hyprland.lua` (greeter) | Bibata-Modern-Ice, size 14 everywhere |
| Monitor scale | `hypr/monitors.lua` | `1.25` - set via CLI only, see Scaling gotchas |
| Terminal font | `foot/foot.ini` | JetBrainsMono Nerd Font size 8 |
| Terminal transparency | `foot/foot.ini` | `alpha=0.85` under `[colors-dark]`, NOT `[main]` |
| Font weight (global) | `fontconfig/conf.d/51-embolden-jetbrains.conf` | synthetic embolden - only Regular/Bold faces are installed, no Medium/SemiBold to switch to |
| Active theme | `omarchy/themes/crimson-core/` | `crimson-core` - custom, see the section above |
| Bar background | generated from `crimson-core/colors.toml` `background` | `#0e0d0c`, alpha `1.0` - no `shell.toml` overlay is shipped for this theme, so the generated one is used as-is |
| Bar transparency toggle | `omarchy/shell.json` `bar.transparent` | `false` - **double-clicking the bar's center toggles this**, which is why it seems to change on its own |
| Bar widgets | `omarchy/shell.json` `bar.layout` | left: `gradiscp.workspaces` (dots); center: clock (`ddd d MMM HH:mm`), system-update - **weather and keyboard-layout removed**; right: tray, `gradiscp.claude-status`, agents, bluetooth, network, audio, monitor, power |
| Notification toasts | `omarchy/plugins/gradiscp.notifications` + `crimson-core/shell.notifications.toml` | 320px, background alpha 0.85 with layer blur, red border only for critical - see the bar and notification clones section |
| Per-window opacity | `hypr/hyprland.lua` | foot `0.85/0.80`, Nautilus `0.85/0.75`, Firefox `0.80/0.70/**1.0 fullscreen**` + a title rule forcing streaming sites to `1.0` - both Firefox rules need `override` on every value (see the Fullscreen gotcha) |
| Idle screensaver / lock | `omarchy/shell.json` `idle` | 120s / 180s - the idle lock blanks the panel 5s later; held off only by a fullscreen window with audio (`omarchy-idle-audio-guard`) |
| Boot / login screen | - | stock Omarchy since 2026-09-21, see the boot screen section |

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

## Shell: `config/bashrc` and `git-all`

`~/.bashrc` is linked to `config/bashrc`: Omarchy's bootstrap and default rc,
plus the `h` function that makes the terminal opaque while herdr runs (herdr
draws on the terminal's default background, which foot renders at alpha
0.85). **The three `ssh*` aliases that used to live there were dropped on
2026-09-13 by choice** - they carried Tailscale IPs, ports and user names,
and the repo is public. If they are wanted again, put them in a file that
stays out of the repo, not here.

`bin/git-all` (in `~/.local/bin`): run it in `~/Projects`. `git-all` lists
every repo below the current directory with uncommitted changes, unpushed
commits, branches without upstream and stashes; clean repos get a ✓.
`git-all fetch` fetches with `--prune` everywhere, `git-all pull` fast-forwards
clean repos (dirty ones are skipped), `git-all push` pushes branches that have
an upstream and are ahead; branches without upstream are only listed, since
pushing them creates them on origin. Status never touches the network (see
`git-remote.md`); the other three ask for the key passphrase per repo unless
an ssh-agent runs. "no upstream" on a branch that *is* on origin (two repos
had that on 2026-09-13, created locally and pushed without `-u`) is fixed
with `git branch --set-upstream-to=origin/<branch>`.

**herdr after a reboot** (checked in herdr's session-state docs and the
server log): the layout, tabs and directories come back, the processes do
not - every pane is a fresh shell. Claude sessions are resumed automatically
only with the herdr Claude integration, which reports each session's id via a
`SessionStart` hook; it was `not installed` here until 2026-09-13
(`herdr integration install claude`, now run by install.sh). Sessions
started before the hook existed are not known to herdr and have to be
resumed by hand once (`/exit`, `claude --resume`).

## 2026-09-13 bloat audit - what went and what stayed

Three read-only audits (packages/services, desktop layer, repo
reproducibility), findings re-checked before acting. The rule the owner set:
lean, containerize anything real, reproducible from this repo in one run.

**Removed** (`remove-unwanted-apps.sh`, ~1.8 GiB with dependencies; nothing
from Omarchy, Hyprland, the shell or the boot chain): libreoffice, clang/llvm,
dotnet, ruby/tobi-try, mariadb-/postgresql-libs, yt-dlp (+deno), tesseract,
webkit2gtk, frei0r (+opencv), qemu-user-static, cups and print tools,
chromium-widevine. Also `chromium` itself is on that list now - it is in
Omarchy's base set and had only been removed by hand, so a fresh install
kept it. Live-only cleanups: ~/.config leftovers of removed apps (chromium
alone 469 MB), old mise tool versions (707 MB).

**Kept on purpose:** the pacman cache at two versions - `omarchy update` runs
`paccache -rk2` itself as the offline downgrade path, so don't prune to one.
`noto-fonts-cjk` (boxes in Firefox without it), non-Intel `linux-firmware`
parts (USB network adapters, docks), Xwayland (Obsidian/Electron), fcitx5
(CapsLock compose), avahi (`.local` lookups), udiskie, tailscale, docker.

**Dead entries fixed** via `config/omarchy/extensions/omarchy-menu.jsonc`
and `bindings.lua`: the Share submenu (every entry ends in the uninstalled
`localsend`) is hidden by a `when`, the Learn pages open via
`omarchy-launch-browser` (the webapp launcher needs Chromium), SUPER+CTRL+S
and SUPER+CTRL+ALT+W are unbound, the invisible keyboard-layout widget left
the bar. **A menu override replaces the stock entry completely** - missing
fields become defaults (label = id), they are not inherited - so overrides
carry every stock field; the lines were copied out of the stock file with
`sed` to keep the glyphs byte-identical.

**Not worth doing here:** an Arch-news-before-update check. Omarchy serves
`core`/`extra`/`multilib` from its own curated `stable-mirror.omarchy.org`
and snapshots before every update; `omarchy update` also prunes orphans and
the cache itself.

## 2026-09-21 audit - second pass

Four read-only audits (scripts, shell plugins, configs/packages/docs,
upstream research), findings re-checked before acting. Upstream Omarchy
(now `github.com/omacom/omarchy`, still 4.0.4) has none of the custom
pieces natively - lock clock, in-lock screensaver, media idle-inhibit, close
confirmation, agent widget all exist only as open PRs - so nothing here was
replaced by stock; the pass removed duplication and fixed what the audits
found. What changed, beyond what the sections above already say:
`install.sh` runs the text-size step *before* linking `foot.ini`
(`omarchy-display-text-size` edits it with a plain `sed -i`, which turned
the fresh link back into a copy) and ends with `omarchy-drift-check` instead
of its own link loop; the menu extension and `Docker.desktop` are linked;
`remove-unwanted-apps.sh` calls `omarchy-pkg-drop` instead of re-implementing
it; `omarchy-drift-check` builds a link beside a copy and renames it over
(the old mv-then-ln could leave nothing at the path); `claude-notify` writes
its state file *before* the toast (a fast click read the previous prompt's
headline); the close dialog selects a button on real pointer movement only
(stock `PointerMoveGate` - a synthetic hover could preselect "Schließen");
Escape closes the lock preview; the bar widget polls every 5s instead of 2s;
`blur.ignore_opacity` (Hyprland's default), `init.defaultBranch = master`
and mise's `auto_prune = false` (kept three `claude` versions, 639 MB) are
gone; `ansible` and `python-proxmoxer` are in `packages.txt`.
`~/.claude/settings.json` uses `$HOME` in the herdr hook path - herdr still
reports the integration as `current`.

**Silent drift of the plugin clones is the one thing still unguarded:**
`gradiscp.notifications/{Service.qml,NotificationLogic.js}` and
`gradiscp.idle/IdleModel.js` are byte-identical to stock today and will
diverge on the next `omarchy update` without anyone noticing. Partial clones
are not possible (the loader resolves entry points and sibling types inside
the clone's own directory only). A `diff` of those files against
`/usr/share/omarchy/shell/plugins/<clonedFrom>/` after updates is the check
to add if that ever bites.

## Syncing to a new machine

On a fresh Omarchy install, clone the repo and run `./install.sh`. It:

1. installs `packages.txt` (pacman list, then an `[aur]` section via yay;
   `-S --needed`, never `-Sy`) and sets up tailscaled,
2. symlinks every config (`link` lines - keep them one per line, the drift
   check parses them): hypr, shell.json, the gradiscp plugins, the
   crimson-core theme, the menu extension, foot (after the text-size step,
   see the audit section), fontconfig, nvim, herdr, git, mise (then
   `mise install`), mimeapps + `Docker.desktop`, the scripts in `bin/`, the
   Claude settings and rules, the idle-audio-guard unit, and the drift check
   as a post-update hook,
3. GTK settings, runs `remove-unwanted-apps.sh`, applies the theme (a theme
   does nothing until `omarchy theme set` generates its files), restarts the
   shell,
4. runs `omarchy-drift-check --quiet`, which re-links any copy left behind
   and reports what differs.

Still manual, printed at the end: monitor scale for a different panel,
the SSH key, `sudo tailscale up`, Firefox Sync.
