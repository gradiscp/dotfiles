# dotfiles

Omarchy config for my laptop (built-in 1920x1080 panel at scale 1). This
file holds only what is true now and must not be broken: the invariants and
the traps. History lives in commit messages and in the incidents repo
(`~/Projects/paulgradischnig/incidents`); the overview and the keybind table
live in `README.md`; component details live in the headers of the scripts
and plugins themselves. Budget: 12 KiB. The principles that decide what
belongs here at all (stock first, lightweight, private, simple,
reproducible) are in `README.md`; apply them to every suggestion.

## Repo rules

- **Public repo: nothing private.** No IPs, hostnames, ports, user names of
  other machines, credentials, private e-mail addresses, absolute home
  paths (`$HOME`, `%h`, `~` instead), employer or private project names.
  Machine-specific things go in untracked files: `~/.config/git/config.local`
  (extra git identities, pulled in by a plain `[include]`) and
  `config/claude/rules/*.local.md` (gitignored, still loaded through the
  `~/.claude/rules` link).
- **Git identity is the global one** (`Paul Gradischnig` /
  `92756104+gradiscp@users.noreply.github.com`). Never set a local
  `user.name`/`user.email` in this repo and never "fix" the global one;
  `git log --format=%ae | sort -u` must show that single address.
- **`install.sh` `link` lines stay one per line.** `omarchy-drift-check`
  parses them (plus the `config/hypr/*.lua` loop), so that is the one list.
- **A repo edit is a live edit** - most of `~/.config` links here. After a
  Hyprland edit, `hyprctl configerrors` must be empty.
- **Files identical to Omarchy's stock copy are not kept in the repo.**
  `hypr/hyprland.lua`, `hypr/autostart.lua`, `hypr/input.lua`, `foot.ini`
  and `.bashrc` are stock plain files live. Launchers under
  `~/.local/share/applications` are never linked: Omarchy migrations `cp`
  onto those paths (through a link they once wrote into this repo).
- **`git add <paths>`, not `git add -A`**, and `git diff` first: tools write
  through the links (below), and a sweep commits whatever they wrote.

## Symlink drift

Omarchy's tools sometimes replace a link with a plain file when they write
(`omarchy-shell-config` `mv`s over `shell.json`, `omarchy display text
size` over `shell.toml`, `omarchy-hyprland-monitor-scaling` runs `sed -i` without
`--follow-symlinks`). Then the repo file changes nothing live, and
`hyprctl reload` still reports success. Others write *through* the link,
straight into the repo, which the drift check cannot see:

- After any `omarchy hyprland|bar|theme|display ...` command, or when an edit
  "doesn't apply": run `omarchy-drift-check` first, then verify with
  `hyprctl binds` / `hyprctl configerrors` - never assume. It re-links copies
  identical to the repo and reports ones that differ; a differing copy
  usually holds a change made through Omarchy's UI - copy it into the repo,
  then re-run. It also runs as an `omarchy update` post-update hook and
  reports packages or launchers from the removal list that are back
  (`remove-unwanted-apps.sh --check`) and a Brave policy copy that differs.
- **Write-through writers:** Claude Code into `settings.json` (`/model`,
  "always allow"); `mise use -g` (any Omarchy lazy wrapper in `~/.local/bin`,
  `omarchy default agent`) into `mise/config.toml`; Omarchy's browser
  installer and two migrations into `brave-origin-flags.conf`; the
  default-browser menu into `mimeapps.list`; `herdr integration install
  claude` into `settings.json` with an absolute home path. A surprise diff in
  one of these files is a tool's doing: revert it, do not commit it.
- `herdr integration install claude`: `install.sh` runs it only before the
  link exists and only if its hook script is missing. To upgrade the hook
  later: run it, then `git checkout -- config/claude/settings.json`.
- The default agent is the file `~/.config/omarchy/defaults/agent`, written
  by `install.sh`; never `omarchy default agent` (see above).
- A dangling theme link does not show: the desktop keeps rendering the
  generated copy in `~/.local/state/omarchy/current/theme/`. If a
  theme-dir-reading command behaves oddly, check
  `ls -laL ~/.config/omarchy/themes/` first.

## Hyprland

- **Laptop scale only via `omarchy hyprland monitor scaling <N>`**, never a
  hand edit of the `omarchy_monitor_scale` line in `monitors.lua` (hand
  edits got reset; the catch-all monitor rule also pulls a stale value back
  when an external display is plugged in). Intended value: 1. Run the drift
  check afterwards. The external monitors in that file carry literal
  `scale =` values on purpose: the command rewrites the variable, and a
  shared variable dragged the laptop to the 4K monitor's 1.6 once.
- **`~/.local/state/omarchy/workspace-layouts/` beats the global layout.**
  `SUPER+H` (toggle layout) writes a per-workspace override there that
  silently beats `layout = "scrolling"` and survives reboots. When windows
  tile or resize wrongly on some workspaces only, `ls` that directory first;
  fix with `rm ~/.local/state/omarchy/workspace-layouts/*.lua && hyprctl reload`.
- **`rounding = 0` stays explicit** in `looknfeel.lua`: a theme's own
  `hyprland.lua` loads before it and may set a radius (stock solitude: 6).
  The shell reads the radius only at start: `omarchy restart shell` after
  changing it. No blur, no opacity rules: everything else is stock.
- **`hl.unbind` matches the key string as written** - spell it like stock
  (`SUPER + SHIFT + CTRL + R`). Hyprland runs *every* matching bind, so a
  reused chord must be unbound first. Reboot is not on bare `CTRL+SHIFT+R`
  (browser hard-refresh).
- **No bare Super-tap binding** (`SUPER + SUPER_L` with `release = true`):
  it fires on every Super press that ran no other bind. The menu is on
  `SUPER+SPACE` only. Don't re-add it without asking.
- **Unbound stock keys** (webapps, Spotify, Signal, 1Password, Obsidian,
  cliamp, Share, weather, OCR, tmux, Docker TUI, screen recording): stock's
  `{ omarchy = ... }` launchers offer to *install* a missing app on
  keypress, which is not wanted; the rest point at removed packages.
  `omarchy_preinstalled_bindings = false` would also kill the working
  Omawrite/herdr keys, hence the explicit list.
- A fullscreen browser holds idle off via `idle_inhibit = "fullscreen"` on
  Omarchy's `chromium-based-browser` tag; Omarchy's regex does not know the
  `brave-origin` class, so `looknfeel.lua` tags it first.

## Omarchy shell and plugins

- **`service`/`panel`/overlay plugins do not hot-reload.** After editing
  `gradiscp.closeconfirm`, run `omarchy restart shell`; otherwise the old
  code keeps running without an error. Bar widgets and `shell.json` do
  hot-reload.
- **Cloning a `kind: bar` plugin is broken** here: the whole bar disappears.
- **Plugin clones drift silently** (a clone never follows stock updates;
  partial clones are not possible). The only clone left is
  `gradiscp.workspaces`, which keeps `moduleName: "omarchy.workspaces"` on
  purpose (IPC routing via `clonedFrom`). Idle, lock and notifications are
  stock since 2026-10-15.
- **Themes are stock only** (the kept list is in `remove-unwanted-apps.sh`).
  Own backgrounds for a stock theme go in
  `config/omarchy/backgrounds/<theme>/` (linked; sorted before the theme's
  own, seen after `omarchy theme set <name>`). Wallpapers are **added as
  downloaded - do not re-encode them** (the compositor downscales a 4K file
  better than any re-compression).
- **`bar.transparent` is toggled by double-clicking the bar's centre** - a
  stock gesture, not drift.
- **There is no `omarchy bar remove`**; delete the entry from `bar.layout`.
- **A menu override replaces the stock entry completely** (missing fields
  become defaults), so `omarchy-menu.jsonc` entries carry every stock field.
- **Browser is Brave Origin** (`omarchy install browser brave-origin`, AUR).
  Privacy defaults are managed policies from `config/brave/privacy.json`
  (root-owned copy; the drift check compares it); what no policy covers is
  in the CHEATSHEET. The stock webapps work with it but are not wanted:
  launchers deleted, keys unbound.

## Lock and idle

- **Never build a passwordless lock or "privacy cover" without asking
  explicitly.** One was built from a misread request and deleted; it is a
  security decision, not styling.
- Lock is stock `omarchy-system-lock` everywhere (SUPER+L, idle); ask
  before adding a lock variant again.
- Known upstream crash: Hyprland can segfault on a lid/hotplug event while
  the panel is *blanked* under a lock. Accepted
  (`~/.cache/hyprland/hyprlandCrashReport*.txt`).
- **"Never locks"**: check `omarchy-shell idle status` (stay-awake toggle,
  stock `SUPER+CTRL+I`) and `hyprctl clients` for a fullscreen browser
  window.
- QML animations: never assign to a running animation's properties from
  inside it (restarts it, recursion, shell hang; `pkill -f quickshell`
  recovers). Keep `<`, `>`, `&` out of StyledText.

## Claude Code

- **`tui` stays unset** (no fullscreen renderer) while
  [herdr#3329](https://github.com/herdrdev/herdr/issues/3329) is open: herdr
  corrupts alternate-screen panes on resize, and Ctrl+L does not repair it
  (`/exit` + `claude --resume` does). Change renderer settings between
  sessions, not under running ones (incidents repo, 2026-09-12).
- Running sessions keep the hook command they loaded. After changing a hook
  path in `settings.json`, restart the sessions or leave something at the
  old path.
- `config/claude/rules/` is linked as a whole directory to
  `~/.claude/rules/`: one topic per file, no `paths:` frontmatter (it would
  make a rule load only on matching reads).
- The `Read`/`Edit` deny list covers Claude's file tools, the Bash file
  commands it recognises (`cat`, `head`, `sed`, `tee`, redirections) and
  nothing else (`grep -r`, scripts): a guard rail, not a boundary.
- `claude-notify` logs every decision to `$XDG_RUNTIME_DIR/claude-notify/log`;
  read it before debugging a missing toast.
- **Only Claude Code via mise.** Omarchy's installer and migrations drop lazy
  `~/.local/bin` wrappers for other agents and tools that install on first
  run; `install.sh` removes them (check `ls ~/.local/bin` and `mise ls`
  after an update). The `omarchy.agents` widget polls only Claude: its
  codex poll once re-added codex through such a wrapper. node is not in
  mise: claude is a native binary, pnpm brings the system `nodejs`.

## Packages and boot

- **Never put `NoExtract` on the Plymouth/SDDM theme dirs**
  (`usr/share/plymouth/themes/omarchy/*`): pacman still removes the old
  files, so an `omarchy-settings` upgrade left a bare-text LUKS prompt and a
  black greeter. Recovery: drop the rule, `sudo pacman -S omarchy-settings`.
  The boot and login screens are stock Omarchy.
- The stock-theme `NoExtract` (`usr/share/omarchy/themes/*` with one `!`
  exception per kept theme) is intended; `remove-unwanted-apps.sh` writes it
  from its `keep_themes` list and the drift check verifies it. `omarchy
  channel set` rewrites `pacman.conf` and brings the themes back until the
  next run of the script.
- Any `pacman -S` (typed, or Omarchy's Install menu) can bring a removed
  package back; `remove-unwanted-apps.sh` is re-runnable and the drift check
  reports what came back.
- `packages.txt` installs with `-S --needed`, never `-Sy` (partial upgrade).
- No fingerprint (the old laptop's EgisTec EH57E has no libfprint driver);
  check libfprint's device list before setting one up on another machine.
- The cursor is one Bibata variant fetched by `install.sh` from a pinned
  release URL with a checksum into `~/.local/share/icons` (1.7 MB download,
  27 MB unpacked); the 322 MB AUR package was dropped on purpose.
- JetBrains Mono serves `sans-serif`/`serif` too: `51-jetbrains.conf` hooks
  in after Omarchy's `50-omarchy.conf` (which assigns Liberation first) with
  `prepend`, so a font an app asks for by name still wins. Delete its two
  `match` blocks to get normal web fonts back.
- fcitx5 is removed; `config/environment.d/10-omarchy-fcitx.conf` masks
  Omarchy's input-method variables (same file name, takes effect at login).
