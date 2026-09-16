-- Hyprland config for the SDDM greeter (seen after a logout; boots autologin).
-- Installed to /usr/local/share/sddm/hyprland.lua by install.sh and selected
-- by config/sddm/20-greeter.conf. Omarchy's own file
-- (/usr/share/sddm/hyprland.lua) sets no monitor scale, so Hyprland picked
-- "auto" for this panel and the whole greeter came up zoomed compared to the
-- desktop. Everything below mirrors the desktop: the three Omarchy settings,
-- then the same scale and cursor as hypr/monitors.lua and hypr/looknfeel.lua.
hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },
  animations = {
    enabled = false,
  },
})

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.25 })

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "14")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "14")
