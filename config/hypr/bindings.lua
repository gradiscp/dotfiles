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

-- Open the Omarchy menu on a bare tap of the Super key itself, *in addition
-- to* the stock SUPER+SPACE - both work. SUPER+SPACE was unbound here at one
-- point; it isn't anymore, the default in
-- default/hypr/bindings/utilities.lua stands.
-- The bare-tap bind is a release bind on the modifier itself; Hyprland only
-- fires it when no other bind ran while Super was held, which is why
-- SUPER+SPACE (or SUPER+1, SUPER+L, ...) doesn't also pop the menu on
-- release.
o.bind("SUPER + SUPER_L", "Omarchy menu", "omarchy-menu toggle", { release = true })

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
