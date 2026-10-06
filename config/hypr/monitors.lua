-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Samsung Odyssey G3 at 60 instead of 144 Hz: with the Alienware next to it the
-- Anker 553 dock link ran at ~89 %, which gave sparkles and short blackouts on
-- both monitors (incidents repo, 2026-10-02). Matched by description because
-- the DP-n names change on every dock reset. Delete to go back to 144 Hz.
-- Mounted in portrait: transform 1 = rotated 90 degrees, 3 = the other way
-- round (use 3 if the picture is upside down).
hl.monitor({ output = "desc:Samsung Electric Company LS24AG30x", mode = "1920x1080@60", position = "auto", scale = omarchy_monitor_scale, transform = 1 })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
