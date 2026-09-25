# dotfiles

Omarchy config for a Samsung Galaxy Book Pro 360 (eDP-1, 1920x1080, scale
1.25). This file holds only what is true now and must not be broken: the
invariants and the traps. History lives in commit messages and in the
incidents repo (`~/Projects/paulgradischnig/incidents`); the overview and
the keybind table live in `README.md`; component details live in the
headers of the scripts and plugins themselves. Budget: 12 KB.

## Repo rules

- **Public repo: nothing private.** No IPs, hostnames, ports, user names of
  other machines, credentials, private e-mail addresses, absolute home
  paths (`$HOME`, `%h`, `~` instead) or names of private projects. The old
  `ssh*` aliases were dropped from `config/bashrc` for this reason; such
  things go in a file outside the repo.
- **Git identity is the global one** (`Paul Gradischnig` /
  `92756104+gradiscp@users.noreply.github.com`). Never set a local
  `user.name`/`user.email` in this repo and never "fix" the global one;
  `git log --format=%ae | sort -u` must show that single address.
- **`install.sh` `link` lines stay one per line.** `omarchy-drift-check`
  parses them (plus the `config/hypr/*.lua` loop), so that is the one list.
- **A repo edit is a live edit** - most of `~/.config` links here. After a
  Hyprland edit, `hyprctl configerrors` must be empty.

## Symlink drift

Omarchy's tools replace links with plain files when they write
(`omarchy-shell-config` `mv`s over `shell.json`, `omarchy theme set` does
too, `omarchy-hyprland-monitor-scaling` and `omarchy-display-text-size` run
`sed -i` without `--follow-symlinks`). Then the repo file changes nothing
live, and `hyprctl reload` still reports success.

- After any `omarchy hyprland|bar|theme|display ...` command, or when an edit
  "doesn't apply": run `omarchy-drift-check` first, then verify with
  `hyprctl binds` / `hyprctl configerrors` - never assume. It re-links copies
  identical to the repo and reports ones that differ; a differing copy
  usually holds a change made through Omarchy's UI - copy it into the repo,
  then re-run. It also runs as an `omarchy update` post-update hook.
- `install.sh` runs `omarchy display text size` *before* linking `foot.ini`
  for the same reason.
- `~/.claude/settings.json` is a link too, and Claude Code rewrites it
  (`/model`, `/config`, "always allow"). A plain file there goes back into
  `config/claude/` and gets relinked.
- A dangling theme link does not show: the desktop keeps rendering the
  generated copy in `~/.local/state/omarchy/current/theme/`. If a
  theme-dir-reading command behaves oddly, check
  `ls -laL ~/.config/omarchy/themes/` first.
- Files identical to Omarchy's stock copy are not kept in the repo
  (`hypr/autostart.lua`, `hypr/input.lua`, `Docker.desktop` are stock plain
  files live). `Docker.desktop` must stay a plain file: Omarchy migrations
  `cp` onto that path, and through a link they wrote into this repo.

## Hyprland

- **Monitor scale only via `omarchy hyprland monitor scaling <N>`**, never a
  hand edit of `monitors.lua` (hand edits got reset; the catch-all monitor
  rule also pulls a stale value back when an external display is plugged in).
  Intended value: 1.25. Run the drift check afterwards.
- **`~/.local/state/omarchy/workspace-layouts/` beats the global layout.**
  `SUPER+H` (toggle layout) writes a per-workspace override there that
  silently beats `layout = "scrolling"` and survives reboots. When windows
  tile or resize wrongly on some workspaces only, `ls` that directory first;
  fix with `rm ~/.local/state/omarchy/workspace-layouts/*.lua && hyprctl reload`.
  This bit twice and contributed to the herdr incident below.
- **Opacity rules:** up to three values (`active inactive fullscreen`, a
  fourth errors), and each is *multiplied* by the global one unless followed
  by `override` - Firefox and the streaming-site rule need `override` on
  every value. `hyprctl getprop <win> opacity_fullscreen` reads `1` either
  way, so it proves nothing; `opacity_fullscreen_override` does.
  `decoration.fullscreen_opacity` (0.9) applies to everything else.
- **Firefox opacity targets the `firefox-based-browser` tag**, not the class:
  Omarchy's `default/hypr/apps/browser.lua` forces tagged windows to 1.0 and
  loads first.
- **Title regexes must match the whole title:** `(?i).*(prime video).*`, not
  `(?i)(prime video)`. Title rules are re-applied on title change.
- **`hl.unbind` matches the key string as written** - spell it like stock
  (`SUPER + SHIFT + CTRL + R`). Hyprland runs *every* matching bind, so a
  reused chord must be unbound first. Reboot is not on bare `CTRL+SHIFT+R`
  (browser hard-refresh).
- **No bare Super-tap binding** (`SUPER + SUPER_L` with `release = true`):
  it fires on every Super press that ran no other bind. The menu is on
  `SUPER+SPACE` only. Don't re-add it without asking.
- **Unbound stock keys** (webapps, Spotify, Signal, 1Password, cliamp, Share,
  weather) point at things not installed here; `command -v` before re-adding
  any. `omarchy_preinstalled_bindings = false` would also kill the working
  Obsidian/Omawrite/herdr/lazydocker/tmux keys, hence the explicit list.

## Omarchy shell and plugins

- **`service`/`panel`/overlay plugins do not hot-reload.** After editing
  `gradiscp.lock`, `.idle`, `.notifications` or `.closeconfirm`, run
  `omarchy restart shell`; otherwise the old code keeps running without an
  error. (`rescanPlugins` only updates the registry.) Bar widgets and
  `shell.json` do hot-reload.
- **Cloning a `kind: bar` plugin is broken** in this Omarchy version: a
  byte-identical clone makes the whole bar disappear (its `required
  property`s are set after creation by `Loader`). Widget and service clones
  work.
- **Plugin clones drift silently.** Unchanged files in the clones
  (`gradiscp.notifications/{Service.qml,NotificationLogic.js}`,
  `gradiscp.idle/IdleModel.js`) do not follow stock updates. After an
  `omarchy update`, `diff` them against
  `/usr/share/omarchy/shell/plugins/<clonedFrom>/`. Partial clones are not
  possible. `gradiscp.workspaces` keeps `moduleName: "omarchy.workspaces"` on
  purpose (IPC routing via `clonedFrom`).
- **Theme `shell.toml` vs `shell.<section>.toml`:** a theme's `shell.toml`
  *replaces* the generated file (~200 lines to own forever - crimson-core
  ships none). `shell.<section>.toml` replaces only that section, so it must
  repeat *every* key of it: `shell.notifications.toml` holding only
  `background-alpha` would drop `border`, `text` and `countdown`.
- **`bar.transparent` is toggled by double-clicking the bar's centre** - a
  stock gesture, not drift. Partial translucency is `background-alpha` in a
  section override instead.
- **There is no `omarchy bar remove`**; delete the entry from `bar.layout`.
- **A menu override replaces the stock entry completely** (missing fields
  become defaults), so `omarchy-menu.jsonc` entries carry every stock field.
- **Webapps need Chromium.** `omarchy-launch-webapp` falls back to
  `chromium.desktop` for any non-Chromium default browser, and Chromium is
  uninstalled - so webapp `.desktop` files and binds are removed. Use a
  Firefox tab, or reinstall Chromium as a runtime, if one is ever wanted.
- New wallpapers and `colors.toml` edits are only seen after
  `omarchy theme set crimson-core` (`current/theme/` is a copy). Wallpapers
  live in `themes/crimson-core/backgrounds/`, numbered in cycle order
  (`SUPER+CTRL+SPACE`), **1920x1080 / JPEG quality 85** - the panel's size,
  and what keeps a public repo small (a 4K original is 3-5 MB, the scaled
  one ~200 KB). `wallpapers/` at the repo root is storage only: files there
  are in no cycle and linked nowhere.

## Lock and idle

- **Never build a passwordless lock or "privacy cover" without asking
  explicitly.** One was built from a misread request and deleted; it is a
  security decision, not styling.
- The idle lock command has flipped twice (`omarchy-system-lock` <->
  `omarchy-lock-light`); it is `omarchy-system-lock` (blanks the panel) now,
  by request. Ask before swapping it. The `isLocked` guard in
  `gradiscp.idle` stays - it keeps an idle lock from hitting a `SUPER+L`
  session.
- Known upstream crash: Hyprland can segfault on a lid/hotplug event while
  the panel is *blanked* under a lock. Accepted; `SUPER+L` never blanks.
  Evidence is in `~/.cache/hyprland/hyprlandCrashReport*.txt`.
- **"Never locks"**: check `ls ~/.local/state/omarchy/indicators/` and
  `omarchy-shell idle status` before suspecting the plugins -
  `omarchy-idle-audio-guard` holds `stay-awake` only for audio *and* a real
  fullscreen window (`fullscreen == 2`). Do not set
  `MOZ_WAKE_LOCK_TYPE=WaylandIdleInhibit` instead: it inhibits for any audio.
- `MatrixRain.qml`: never assign to a running animation's properties from
  inside it (restarts it, recursion, the shell hangs - `pkill -f quickshell`
  recovers). Keep `<`, `>`, `&` out of the glyph set (StyledText).
- SUPER+W (close guard) cannot be tested with `wtype`; it needs a real keyboard.

## Claude Code

- **`tui` stays unset** (no fullscreen renderer) while
  [herdr#3329](https://github.com/herdrdev/herdr/issues/3329) is open: herdr
  corrupts alternate-screen panes on resize, and Ctrl+L does not repair it
  (`/exit` + `claude --resume` does). Change renderer settings between
  sessions, not under running ones. Postmortem:
  `~/Projects/paulgradischnig/incidents/2026-09-12-herdr-claude-fullscreen-garbled.md`.
- Running sessions keep the hook command they loaded. After changing a hook
  path in `settings.json`, restart the sessions or leave something at the
  old path.
- `config/claude/rules/` is linked as a whole directory to
  `~/.claude/rules/`: one topic per file, no `paths:` frontmatter (it would
  make a rule load only on matching reads). Check with `/context` in a new
  session.
- `claude-notify` logs every decision to `$XDG_RUNTIME_DIR/claude-notify/log`;
  read it before debugging a missing toast.

## Packages and boot

- **Never put `NoExtract` on the Plymouth/SDDM theme dirs**
  (`usr/share/plymouth/themes/omarchy/*`): pacman still removes the old
  files, so an `omarchy-settings` upgrade left a bare-text LUKS prompt and a
  black greeter. Recovery: drop the rule, `sudo pacman -S omarchy-settings`.
  `remove-unwanted-apps.sh` removes it, the drift check reports it.
- The stock-theme `NoExtract` (`usr/share/omarchy/themes/*`) is intended;
  undo it by deleting the line and `sudo pacman -S omarchy`.
- Keep the pacman cache at two versions (`omarchy update` runs
  `paccache -rk2` as the downgrade path).
- `packages.txt` installs with `-S --needed`, never `-Sy` (partial upgrade).
- No fingerprint: the EgisTec EH57E (`1c7a:057e`) has no packaged libfprint
  driver. The experimental one would need a self-built libfprint - if ever,
  isolated under `/opt`, never replacing the system one.
- Firefox follows the system scale; a `layout.css.devPixelsPerPx` in a
  `user.js` (profile under `~/.config/mozilla/`) would override `prefs.js` on
  every start. There is none - keep it that way.
- foot's `alpha` belongs under `[colors-dark]`, not `[main]`.
- The second NVMe plan (not done, destructive, needs an explicit go-ahead):
  `docs/nvme-plan.md`.
