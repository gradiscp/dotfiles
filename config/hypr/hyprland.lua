-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Let the bar (a layer-shell surface, not a regular window) blur too, so
-- shell.json's "transparent" bar setting actually looks transparent instead
-- of just murky/black.
hl.layer_rule({ match = { namespace = "omarchy-bar" }, blur = true, ignore_alpha = true })

-- Make the terminal visibly translucent (foot doesn't follow the
-- decoration.opacity default the way regular windows do).
o.window("foot", { opacity = "0.85 0.80" })

-- Nautilus stays clearly translucent even while focused/in use, not just
-- when unfocused (the global default-opacity rule is too subtle for this).
o.window("org.gnome.Nautilus", { opacity = "0.85 0.75" })

-- Firefox is a real GTK/Wayland client-side-decorated window (unlike
-- Chromium's own Aura toolkit), so the opacity trick actually works here -
-- but Omarchy's own default/hypr/apps/browser.lua explicitly forces
-- "firefox-based-browser"-tagged windows back to opacity 1.0/0.985
-- (loaded before this file). Overriding the class directly isn't enough to
-- win against that; target the same tag it uses so this applies after it.
o.window({ tag = "firefox-based-browser" }, { opacity = "0.80 0.70" })
