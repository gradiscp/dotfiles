-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- The Omarchy menu is on the stock SUPER+SPACE only (see
-- default/hypr/bindings/utilities.lua - not overridden here).
-- A bare tap of Super used to open it too, via
--   o.bind("SUPER + SUPER_L", "Omarchy menu", "omarchy-menu toggle", { release = true })
-- That is deliberately gone: a release-bind on the modifier itself fires on
-- every Super tap that didn't run another bind, which means it also fires
-- when you press Super, change your mind, and let go. Don't re-add it
-- without asking.

-- Dead default bindings, unbound because the thing behind them isn't here.
-- Checked 2026-08-28 with `command -v`; re-check before re-adding any.
--
-- Apps that were never installed / were removed (see the app-cleanup section
-- in CLAUDE.md). The bind existing without the app means the key does
-- nothing at all - no error, no window - which is worse than the key being
-- free for something else.
hl.unbind("SUPER + SHIFT + M")          -- Spotify
hl.unbind("SUPER + SHIFT + ALT + M")    -- cliamp (music TUI)
hl.unbind("SUPER + SHIFT + G")          -- Signal
hl.unbind("SUPER + SHIFT + SLASH")      -- 1Password

-- Every webapp bind. These all route through omarchy-launch-webapp, which
-- only recognizes Chromium-family browsers and otherwise falls back to
-- chromium.desktop - and Chromium is uninstalled here, so all of them fail
-- with `Path "--app=..." does not exist!`. This is the same root cause that
-- already got the WhatsApp/Discord/YouTube .desktop files deleted; these are
-- the keyboard half of the same problem. Use a normal Firefox tab instead.
hl.unbind("SUPER + SHIFT + A")          -- ChatGPT
hl.unbind("SUPER + SHIFT + ALT + A")    -- Grok
hl.unbind("SUPER + SHIFT + C")          -- HEY Calendar
hl.unbind("SUPER + SHIFT + E")          -- HEY Email
hl.unbind("SUPER + SHIFT + ALT + E")    -- HEY new email
hl.unbind("SUPER + SHIFT + Y")          -- YouTube
hl.unbind("SUPER + SHIFT + ALT + G")    -- WhatsApp
hl.unbind("SUPER + SHIFT + CTRL + G")   -- Google Messages
hl.unbind("SUPER + SHIFT + P")          -- Google Photos
hl.unbind("SUPER + SHIFT + X")          -- X
hl.unbind("SUPER + SHIFT + ALT + X")    -- X post
-- SUPER + SHIFT + S (Google Maps) is not listed here: it is already unbound
-- further down and reused for the screenshot bind.
--
-- Still bound and still working: Obsidian (SUPER+SHIFT+O), Omawrite
-- (SUPER+SHIFT+W), Herdr (SUPER+CTRL+RETURN), Docker/lazydocker
-- (SUPER+SHIFT+D), tmux (SUPER+ALT+RETURN).

-- Persistent workspaces 6-8 so they always show in the bar's workspace
-- indicator, not just once you've actually switched to them.
hl.workspace_rule({ workspace = "6", persistent = true })
hl.workspace_rule({ workspace = "7", persistent = true })
hl.workspace_rule({ workspace = "8", persistent = true })

-- SUPER+L: real lock - password required, display never blanks (the
-- omarchy.lock clone below suppresses the usual 5s auto-blank via a flag
-- file this script sets). Was: SUPER+L -> Toggle workspace layout.
-- For a lock that blanks the display after 5s, use SUPER+SHIFT+L below.
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock (screen stays on)", "omarchy-lock-light")

-- The old SUPER+L action (toggle dwindle/master workspace layout) moved to
-- SUPER+H, which was unused.
o.bind("SUPER + H", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- Screenshot on SUPER+SHIFT+S instead of the PRINT key.
-- Was: PRINT -> Screenshot, SUPER+SHIFT+S -> Google Maps (that webapp
-- shortcut was removed earlier anyway, so nothing lost there).
-- "copy" mode: clipboard only, no file written to ~/Pictures every time.
-- Default "slurp" mode does both - use `omarchy capture screenshot smart save`
-- manually on the rare occasion a file is actually wanted.
hl.unbind("PRINT")
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot smart copy")

-- SUPER+SHIFT+L: full lock, display blanks after 5s. Replaces the default
-- SUPER+CTRL+L for this - that one's unbound now, only SHIFT+L is used.
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + SHIFT + L", "Lock (screen off)", "omarchy-system-lock")

-- CTRL+SHIFT+ESCAPE -> shutdown. No conflicts (Windows' Task Manager
-- shortcut, not used by anything on Linux).
o.bind("CTRL + SHIFT + ESCAPE", "Shutdown", "omarchy-system-shutdown")

-- Reboot on SUPER+CTRL+SHIFT+R, not bare CTRL+SHIFT+R - that's hard-refresh
-- in every browser, a global bind there would break it everywhere.
o.bind("SUPER + CTRL + SHIFT + R", "Reboot", "omarchy-system-reboot")
