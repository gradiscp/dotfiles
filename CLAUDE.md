# dotfiles

Omarchy config for my laptop (built-in 1920x1080 panel at scale 1). This
file holds only what is true now and must not be broken: the invariants and
the traps. History lives in commit messages and in the incidents repo
(`~/Projects/paulgradischnig/incidents`); the overview and the keybind table
live in `README.md`; component details live in the headers of the scripts
and plugins themselves. Budget: 12 KB.

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
  `hypr/hyprland.lua`, `hypr/autostart.lua`, `hypr/input.lua`, `foot.ini`,
  `.bashrc` and `Docker.desktop` are stock plain files live. `Docker.desktop`
  must stay a plain file: Omarchy migrations `cp` onto that path, and through
  a link they wrote into this repo.

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
  then re-run. It also runs as an `omarchy update` post-update hook, where it
  additionally reports stock packages the update reinstalled
  (`remove-unwanted-apps.sh --check`; LibreOffice came back on 2026-09-24).
- `~/.claude/settings.json` is a link too, and Claude Code rewrites it
  (`/model`, `/config`, "always allow"): `git diff` it before every commit and
  commit only what was meant. A plain file there goes back into
  `config/claude/` and gets relinked.
- A dangling theme link does not show: the desktop keeps rendering the
  generated copy in `~/.local/state/omarchy/current/theme/`. If a
  theme-dir-reading command behaves oddly, check
  `ls -laL ~/.config/omarchy/themes/` first.

## Hyprland

- **Laptop scale only via `omarchy hyprland monitor scaling <N>`**, never a
  hand edit of the `omarchy_monitor_scale` line in `monitors.lua` (hand
  edits got reset; the catch-all monitor rule also pulls a stale value back
  when an external display is plugged in). Intended value: 1. Run the
  drift check afterwards. The external monitors in that file carry literal
  `scale =` values on purpose: the command rewrites the variable, and a
  shared variable dragged the laptop to the 4K monitor's 1.6 once.
- **`~/.local/state/omarchy/workspace-layouts/` beats the global layout.**
  `SUPER+H` (toggle layout) writes a per-workspace override there that
  silently beats `layout = "scrolling"` and survives reboots. When windows
  tile or resize wrongly on some workspaces only, `ls` that directory first;
  fix with `rm ~/.local/state/omarchy/workspace-layouts/*.lua && hyprctl reload`.
  This bit twice and contributed to the herdr incident below.
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
  cliamp, Share, weather): stock's `{ omarchy = ... }` launchers offer to
  *install* a missing app on keypress, which is not wanted.
  `omarchy_preinstalled_bindings = false` would also kill the working
  Omawrite/herdr/lazydocker/tmux keys, hence the explicit list.

## Omarchy shell and plugins

- **`service`/`panel`/overlay plugins do not hot-reload.** After editing
  `gradiscp.closeconfirm`, run
  `omarchy restart shell`; otherwise the old code keeps running without an
  error. (`rescanPlugins` only updates the registry.) Bar widgets and
  `shell.json` do hot-reload.
- **Cloning a `kind: bar` plugin is broken** in this Omarchy version: a
  byte-identical clone makes the whole bar disappear (its `required
  property`s are set after creation by `Loader`). Widget and service clones
  work.
- **Plugin clones drift silently** (a clone never follows stock updates;
  partial clones are not possible). The only clone left is the 117-line
  `gradiscp.workspaces`, which keeps `moduleName: "omarchy.workspaces"` on
  purpose (IPC routing via `clonedFrom`). Idle, lock and notifications are
  stock since 2026-10-15: the clones carried ~3700 lines (password code
  included) for a no-blank lock, a clock and a toast style.
- **Theme `shell.toml` vs `shell.<section>.toml`:** a theme's `shell.toml`
  *replaces* the generated file (~200 lines to own forever). The two own
  themes ship only `shell.notifications.toml`, which replaces that one
  section and therefore repeats *every* key of it.
- **`bar.transparent` is toggled by double-clicking the bar's centre** - a
  stock gesture, not drift.
- **There is no `omarchy bar remove`**; delete the entry from `bar.layout`.
- **A menu override replaces the stock entry completely** (missing fields
  become defaults), so `omarchy-menu.jsonc` entries carry every stock field.
- **Browser is Brave Origin** (Omarchy's `omarchy install browser
  brave-origin`, AUR). Privacy defaults are managed policies from
  `config/brave/privacy.json`; what no policy covers is in the CHEATSHEET.
  Omarchy's browser regex does not know the `brave-origin` class, so
  `looknfeel.lua` tags it `chromium-based-browser` itself. The stock webapps
  work with it but are not wanted: launchers deleted, keys unbound.
- **Themes:** Tokyo Night (the one stock theme kept on disk) is the default;
  `crimson-core` and `apple-coast` in `config/omarchy/themes/` stay
  selectable. Their `colors.toml`/wallpaper edits are only seen after
  `omarchy theme set <name>` (`current/theme/` is a copy). Wallpapers are
  **added as downloaded - do not re-encode them**: scaling to 1080p/q85 was
  tried on 2026-09-25 and rejected, the compositor downscales a 4K file
  better than any re-compression.

## Lock and idle

- **Never build a passwordless lock or "privacy cover" without asking
  explicitly.** One was built from a misread request and deleted; it is a
  security decision, not styling.
- Lock is stock `omarchy-system-lock` everywhere (SUPER+L, idle). A
  "screen stays on" light lock existed until 2026-10-15 and was dropped
  with its plugin clone; ask before bringing one back.
- Known upstream crash: Hyprland can segfault on a lid/hotplug event while
  the panel is *blanked* under a lock. Accepted
  (`~/.cache/hyprland/hyprlandCrashReport*.txt`).
- **"Never locks"**: check `omarchy-shell idle status` (stay-awake toggle,
  stock `SUPER+CTRL+I`) and `hyprctl clients` for a fullscreen browser: the
  `idle_inhibit = "fullscreen"` rule on the `chromium-based-browser` tag in
  `looknfeel.lua` is what keeps a film from locking.
- QML animations: never assign to a running animation's properties from
  inside it (restarts it, recursion, shell hang; `pkill -f quickshell`
  recovers). Keep `<`, `>`, `&` out of StyledText.
- SUPER+W (close guard) cannot be tested with `wtype`; it needs a real keyboard.

## Claude Code

- **`tui` stays unset** (no fullscreen renderer) while
  [herdr#3329](https://github.com/herdrdev/herdr/issues/3329) is open: herdr
  corrupts alternate-screen panes on resize, and Ctrl+L does not repair it
  (`/exit` + `claude --resume` does). Change renderer settings between
  sessions, not under running ones. Postmortem:
  `~/Projects/paulgradischnig/incidents/2026-09-12-herdr-claude-fullscreen-garbled.md`.
- `herdr integration install claude` writes a SessionStart hook with an
  absolute home path into `settings.json`; `install.sh` runs it only before
  the link exists and only if its hook script is missing. Never re-run it by
  hand through the link.
- Running sessions keep the hook command they loaded. After changing a hook
  path in `settings.json`, restart the sessions or leave something at the
  old path.
- `config/claude/rules/` is linked as a whole directory to
  `~/.claude/rules/`: one topic per file, no `paths:` frontmatter (it would
  make a rule load only on matching reads). Check with `/context` in a new
  session.
- The `Read`/`Edit` deny list covers Claude's file tools, the Bash file
  commands it recognises (`cat`, `head`, `sed`, `tee`, redirections) and
  nothing else (`grep -r`, scripts): a guard rail, not a boundary.
- `claude-notify` logs every decision to `$XDG_RUNTIME_DIR/claude-notify/log`;
  read it before debugging a missing toast.
- **Only Claude Code via mise.** Omarchy's installer and migrations drop
  lazy `~/.local/bin` wrappers for other agents (codex, copilot, crush,
  cursor-agent, gemini, grok, hermes, muse, omp, opencode, pi) that install
  on first run; `install.sh` removes them (check `ls ~/.local/bin` and
  `mise ls` after an update). The `omarchy.agents` bar widget runs `codex`
  for its usage meter, which through that wrapper wrote codex back into
  `mise/config.toml` once: its codex/fireworks providers stay disabled in
  `shell.json`. node is not in mise: the system `nodejs` (a pnpm dependency)
  is enough.

## Packages and boot

- **Never put `NoExtract` on the Plymouth/SDDM theme dirs**
  (`usr/share/plymouth/themes/omarchy/*`): pacman still removes the old
  files, so an `omarchy-settings` upgrade left a bare-text LUKS prompt and a
  black greeter. Recovery: drop the rule, `sudo pacman -S omarchy-settings`.
  The boot and login screens are stock Omarchy.
- The stock-theme `NoExtract` (`usr/share/omarchy/themes/*` with a `!`
  exception for `tokyo-night`) is intended; `remove-unwanted-apps.sh` writes
  it and the drift check verifies it. Undo by deleting the line and
  `sudo pacman -S omarchy`.
- `omarchy update` can reinstall removed base packages; `remove-unwanted-apps.sh`
  is re-runnable and the drift check reports what came back.
- Keep the pacman cache at two versions (`omarchy update` runs
  `paccache -rk2` as the downgrade path).
- `packages.txt` installs with `-S --needed`, never `-Sy` (partial upgrade).
- No fingerprint (the old laptop's EgisTec EH57E has no libfprint driver);
  check libfprint's device list before setting one up on another machine.
- The cursor is one Bibata variant fetched by `install.sh` from a pinned
  release URL with a checksum into `~/.local/share/icons` (1.7 MB); the AUR
  `bibata-cursor-theme-bin` (322 MB, every variant) was dropped on purpose.
- JetBrains Mono serves `sans-serif`/`serif` too: `51-jetbrains.conf` hooks
  in after Omarchy's `50-omarchy.conf` (which assigns Liberation first).
  Delete its two `match` blocks to get normal web fonts back.
