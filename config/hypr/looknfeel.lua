-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Niri-like side-scrolling layout instead of dwindle.
hl.config({
  general = {
    layout = "scrolling",
  },
})

-- Round window corners instead of sharp ones, and enable blur so
-- translucent windows/bar look good instead of just murky.
hl.config({
  decoration = {
    rounding = 10,
    -- Hyprland forces this opacity on fullscreen windows regardless of the
    -- window's own opacity rule (e.g. SUPER+F on foot/firefox). Default is
    -- 1.0 (fully opaque); keep it translucent instead.
    fullscreen_opacity = 0.9,

    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      ignore_opacity = true,
    },
  },
})

-- Smaller cursor (was 24) to match a 1.25 scaled HiDPI-ish laptop panel,
-- and use Bibata-Modern-Ice instead of the default theme.
hl.env("XCURSOR_SIZE", "14")
hl.env("HYPRCURSOR_SIZE", "14")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
