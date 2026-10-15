-- Personal look'n'feel on top of Omarchy's defaults. Everything not listed
-- here is stock: square corners, no blur, no custom opacity.

-- Niri-like side-scrolling layout instead of dwindle, with thinner gaps
-- (stock is 5/10; 2026-09-16 down from 3/6).
hl.config({
  general = {
    layout = "scrolling",
    gaps_in = 2,
    gaps_out = 3,
    -- border_size stays at Omarchy's 2: 1 was tried and read as too thin.
  },
})

-- Default column_width (0.49) makes a single window look "too small" -
-- half the screen, with a gap of bare desktop next to it. 1.0 = fill the
-- screen exactly like dwindle would for one window.
hl.config({
  scrolling = {
    column_width = 1.0,
  },
})

-- Square corners. Set explicitly (not just left out) because a theme's own
-- hyprland.lua loads before this file and may set a radius (stock solitude
-- uses 6). The shell reads this value only at start: `omarchy restart shell`
-- after changing it.
hl.config({
  decoration = {
    rounding = 0,
  },
})
-- Omarchy gives popped-out windows (tag "pop") rounding = 8 in
-- default/hypr/apps/system.lua; square those too.
o.window({ tag = "pop" }, { rounding = 0 })

-- Bibata-Modern-Ice at 14 instead of the stock Adwaita at 24. Installed by
-- install.sh as a 1.7 MB XCursor theme under ~/.local/share/icons (the AUR
-- package is 322 MB of every variant). No hyprcursor variant exists, so
-- Hyprland falls back to XCursor for it, which is fine.
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "14")
hl.env("HYPRCURSOR_SIZE", "14")
