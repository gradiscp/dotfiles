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

-- Focus on click, not on hover (stock 1 = focus follows the mouse). With a
-- monitor to the right, the scrolling layout's off-screen columns lie where
-- that monitor begins, and crossing the edge with the mouse focused such a
-- hidden column and scrolled to it. 2: hovering moves no focus; a click or
-- a key does, and the wheel still scrolls the window under the pointer.
-- Omarchy's floating workspaces set 0 while active and restore this value.
hl.config({
  input = {
    follow_mouse = 2,
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

-- A fullscreen browser (a film) holds the idle screensaver and lock off, the
-- same way Omarchy does it for Steam and Moonlight. Any fullscreen browser
-- window counts, playing or not; a video in a normal window does not.
-- Omarchy tags Chromium-family windows "chromium-based-browser"
-- (default/hypr/apps/browser.lua), but its regex knows brave-browser, not
-- brave-origin - so tag it here first, which also gives it Omarchy's stock
-- browser treatment (tiled, 1.0/0.985 opacity). Upstream candidate.
o.window("brave-origin", { tag = "+chromium-based-browser" })
o.window({ tag = "chromium-based-browser" }, { idle_inhibit = "fullscreen" })

-- Same gap for the Bitwarden extension's popup window (passkey prompt,
-- pop-out): Omarchy floats it only under Chromium's class
-- (default/hypr/apps/bitwarden.lua); Brave names it brave-<id>-Default.
-- Untagged, the scrolling layout made it a column of its own and scrolled
-- the browser off screen. Floated at its own size, not stock's 875x600:
-- Brave keeps drawing the popup at the width it opened with until the
-- pointer moves over it.
o.window("brave-nngceckbapebfimnlniiiahkandclblb-Default", {
  no_screen_share = true,
  float = true,
  center = true,
})

-- Bibata-Modern-Ice at 14 instead of the stock Adwaita at 24. Installed by
-- install.sh as a 1.7 MB XCursor theme under ~/.local/share/icons (the AUR
-- package is 322 MB of every variant). No hyprcursor variant exists, so
-- Hyprland falls back to XCursor for it, which is fine.
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "14")
hl.env("HYPRCURSOR_SIZE", "14")
