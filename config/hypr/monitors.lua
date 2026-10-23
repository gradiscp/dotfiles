-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- External monitors are matched by description because the DP-n names change
-- on every dock reset, and they carry literal scale values on purpose:
-- `omarchy hyprland monitor scaling` rewrites omarchy_monitor_scale above
-- (the laptop panel), which must not drag the externals along.

-- Samsung Odyssey G3 at 60 instead of 144 Hz: at 144 the dock link ran near
-- capacity and gave sparkles and short blackouts (incidents repo,
-- 2026-10-02). Mounted in portrait: transform 1 = rotated 90 degrees, 3 = the
-- other way round (use 3 if the picture is upside down).
hl.monitor({ output = "desc:Samsung Electric Company LS24AG30x", mode = "1920x1080@60", position = "auto", scale = 1, transform = 1 })

-- Dell Alienware 25" next to it, pinned to 1 like the Samsung (it used to
-- follow the laptop's omarchy_monitor_scale through the catch-all rule).
hl.monitor({ output = "desc:Dell Inc. AW2521HFA", mode = "preferred", position = "auto", scale = 1 })

-- Samsung 32" 4K stands left of the laptop, with its own scale of 1.5
-- (2560x1440 logical; was 1.6).
hl.monitor({ output = "desc:Samsung Electric Company LF32TU87", mode = "preferred", position = "auto-left", scale = 1.5 })
