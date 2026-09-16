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

-- Same for notification toasts: the crimson-core theme ships
-- shell.notifications.toml with background-alpha 0.85, and without blur a
-- translucent toast is hard to read over a busy window.
hl.layer_rule({ match = { namespace = "omarchy-notifications" }, blur = true, ignore_alpha = true })

-- SUPER+W's close question is a translucent strip under the bar, same idea.
hl.layer_rule({ match = { namespace = "gradiscp-closeconfirm" }, blur = true, ignore_alpha = true })

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
-- Third value = fullscreen opacity, so a fullscreen video is solid while a
-- fullscreen terminal stays at decoration.fullscreen_opacity (0.9).
-- The "override" after each value is what makes that true: without it a rule
-- value is MULTIPLIED by the global one, and "1.0" in fullscreen still came
-- out as 1.0 x 0.9 - measured 2026-09-13 on a white fullscreen window: centre
-- pixel 231 without override, 255 with it. active/inactive_opacity are 1.0
-- globally, so override changes nothing for the first two values.
o.window({ tag = "firefox-based-browser" }, { opacity = "0.80 override 0.70 override 1.0 override" })

-- ...and the same for a *windowed* video: streaming sites are matched by
-- window title (Firefox puts the page title in it) and forced fully opaque,
-- so a half-transparent picture is impossible either way. Trade-off: a tab
-- merely *open* on one of these sites is opaque too, not only one that is
-- actually playing - Hyprland can match a title, not a play state.
-- The .* on both ends is required: a title regex has to match the WHOLE title,
-- and Firefox's is "<page title> — Mozilla Firefox". Without them this rule
-- silently never matched anything (verified 2026-09-13 with hyprctl getprop).
o.window(
  { tag = "firefox-based-browser", title = "(?i).*(youtube|netflix|prime video|disney|twitch|mediathek|joyn|dazn|crunchyroll).*" },
  { opacity = "1.0 override 1.0 override 1.0 override" }
)
