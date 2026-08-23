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

-- Open the Omarchy menu on a bare tap of the Super key itself, not
-- SUPER+SPACE. Was: SUPER + SPACE -> Omarchy menu.
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SUPER_L", "Omarchy menu", "omarchy-menu toggle", { release = true })

-- Persistent workspaces 6-8 so they always show in the bar's workspace
-- indicator, not just once you've actually switched to them.
hl.workspace_rule({ workspace = "6", persistent = true })
hl.workspace_rule({ workspace = "7", persistent = true })
hl.workspace_rule({ workspace = "8", persistent = true })

-- SUPER+L: light lock - blurred lock screen, but the display never blanks
-- (background processes like Docker etc. are never affected by locking
-- either way - locking only blocks input/shows the overlay, nothing is
-- suspended). Was: SUPER+L -> Toggle workspace layout (dwindle/master).
-- SUPER+CTRL+L stays the regular full lock (blanks the display after 5s).
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock (screen stays on)", "omarchy-lock-light")

-- The old SUPER+L action (toggle dwindle/master workspace layout) moved to
-- SUPER+H, which was unused.
o.bind("SUPER + H", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- Screenshot on SUPER+SHIFT+S instead of the PRINT key.
-- Was: PRINT -> Screenshot, SUPER+SHIFT+S -> Google Maps (that webapp
-- shortcut was removed earlier anyway, so nothing lost there).
hl.unbind("PRINT")
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")

-- SUPER+SHIFT+L: full lock, display blanks after 5s. Replaces the default
-- SUPER+CTRL+L for this - that one's unbound now, only SHIFT+L is used.
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + SHIFT + L", "Lock (screen off)", "omarchy-system-lock")
