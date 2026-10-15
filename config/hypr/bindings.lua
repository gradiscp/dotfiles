-- Personal keybinding overrides on top of Omarchy's defaults.
-- See current bindings and descriptions: omarchy menu keybindings --print

-- The Omarchy menu is on the stock SUPER+SPACE only (see
-- default/hypr/bindings/utilities.lua - not overridden here).
-- A bare tap of Super used to open it too, via
--   o.bind("SUPER + SUPER_L", "Omarchy menu", "omarchy-menu toggle", { release = true })
-- That is deliberately gone: a release-bind on the modifier itself fires on
-- every Super tap that didn't run another bind, which means it also fires
-- when you press Super, change your mind, and let go. Don't re-add it
-- without asking.

-- Stock keys for apps that are not wanted here (see remove-unwanted-apps.sh).
-- Stock's `{ omarchy = "..." }` launchers offer to INSTALL the app when it is
-- missing, which is exactly what is not wanted, so the keys are unbound.
hl.unbind("SUPER + SHIFT + M")          -- Spotify
hl.unbind("SUPER + SHIFT + ALT + M")    -- cliamp (music TUI)
hl.unbind("SUPER + SHIFT + G")          -- Signal
hl.unbind("SUPER + SHIFT + SLASH")      -- 1Password
hl.unbind("SUPER + SHIFT + O")          -- Obsidian (removed 2026-10-15)

-- Every webapp bind. The webapps themselves (HEY, WhatsApp, X, ...) are not
-- wanted here; remove-unwanted-apps.sh deletes their launchers, these are the
-- keyboard half. Open such sites in a normal browser tab instead.
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
-- Still bound and still working: Omawrite (SUPER+SHIFT+W), Herdr
-- (SUPER+CTRL+RETURN), Docker/lazydocker (SUPER+SHIFT+D), tmux
-- (SUPER+ALT+RETURN).

-- Persistent workspaces 6-8 so they always show in the bar's workspace
-- indicator, not just once you've actually switched to them.
hl.workspace_rule({ workspace = "6", persistent = true })
hl.workspace_rule({ workspace = "7", persistent = true })
hl.workspace_rule({ workspace = "8", persistent = true })

-- SUPER+L: lock, instead of stock's SUPER+CTRL+L (unbound: one lock key).
-- Was: SUPER+L -> Toggle workspace layout, which moved to SUPER+H (unused).
hl.unbind("SUPER + L")
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + L", "Lock", "omarchy-system-lock")
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

-- SUPER+P: jump to the Claude session (herdr pane or plain terminal) that is
-- waiting for a permission - the keyboard half of the claude-notify toast,
-- and it still works after that toast has gone (10s). Was: "Pseudo window",
-- which only means anything in the dwindle layout, not the scrolling one
-- used here.
hl.unbind("SUPER + P")
o.bind("SUPER + P", "Jump to waiting Claude", "claude-notify jump")

-- SUPER+W: close the window, but ask first when it is a terminal with
-- something still running in it (Claude, herdr, ssh, ...) - see
-- bin/window-close-guard. SUPER+W a second time confirms. Every other window
-- closes at once, as stock.
hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close window", "window-close-guard")

-- Dead stock keys found in the 2026-09-13 audit:
-- SUPER+CTRL+S opens the Share menu, and every Share entry ends in localsend,
-- which isn't installed. SUPER+CTRL+ALT+W toggles the weather panel, which
-- only works while the weather widget is in the bar - it was removed.
hl.unbind("SUPER + CTRL + S")
hl.unbind("SUPER + CTRL + ALT + W")

-- CTRL+SHIFT+ESCAPE -> shutdown. No conflicts (Windows' Task Manager
-- shortcut, not used by anything on Linux).
o.bind("CTRL + SHIFT + ESCAPE", "Shutdown", "omarchy-system-shutdown")

-- Reboot on SUPER+CTRL+SHIFT+R, not bare CTRL+SHIFT+R - that's hard-refresh
-- in every browser, a global bind there would break it everywhere. Stock has
-- "Clear reminders" on this chord; Hyprland runs every matching bind, so
-- without the unbind a reboot also wiped the reminders (seen in hyprctl binds).
-- Spelled in stock's modifier order on purpose: hl.unbind matches the string
-- as written, "SUPER + CTRL + SHIFT + R" left both binds in place.
hl.unbind("SUPER + SHIFT + CTRL + R")
o.bind("SUPER + CTRL + SHIFT + R", "Reboot", "omarchy-system-reboot")
