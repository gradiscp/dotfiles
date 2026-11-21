-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Laptop panel at 60 Hz unless the power profile is "performance" (balanced
-- and power-saver cap it, performance gets the panel's 120 Hz). This wraps
-- hl.monitor instead of touching the eDP-1 line below, which belongs to
-- `omarchy hyprland monitor scaling`; Omarchy's clamshell, lid and scaling
-- scripts re-enable the panel through hl.monitor too, so they get the cap.
-- bin/power-profile-hz reloads Hyprland on every profile change. A fixed
-- choice from the Framework panel (`framework-panel refresh-rate 60|120`,
-- kept in $XDG_STATE_HOME/framework/refresh-rate) beats the profile; "auto"
-- or no file follows it. Framework only: the mode below is that panel's, and
-- forcing it on another laptop (1920x1080 panel) gave a small 3:2 picture
-- with black bars left and right.
local function first_line(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local line = file:read("*l")
  file:close()
  return line
end
local function laptop_capped()
  local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
  local choice = first_line(state_home .. "/framework/refresh-rate")
  if choice == "60" then return true end
  if choice == "120" then return false end
  local profile = first_line("/sys/firmware/acpi/platform_profile")
  return profile ~= nil and profile ~= "performance"
end
local is_framework = first_line("/sys/class/dmi/id/sys_vendor") == "Framework"
hl.monitor_uncapped = hl.monitor_uncapped or hl.monitor
hl.monitor = function(rule)
  if is_framework and rule.output == "eDP-1" and not rule.disabled and laptop_capped() then
    rule.mode = "2880x1920@60"
  end
  return hl.monitor_uncapped(rule)
end

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.6 })

-- External monitors are matched by description because the DP-n names change
-- on every dock reset, and they carry literal scale values on purpose:
-- `omarchy hyprland monitor scaling` writes a rule for the focused output
-- (eDP-1 above), so the externals keep theirs whatever the laptop uses.

-- Samsung Odyssey G3 at 60 instead of 144 Hz: at 144 the dock link ran near
-- capacity and gave sparkles and short blackouts (incidents repo,
-- 2026-10-02). Landscape; for portrait add transform = 1 (rotated 90
-- degrees) or 3 (the other way round, if the picture is upside down).
hl.monitor({ output = "desc:Samsung Electric Company LS24AG30x", mode = "1920x1080@60", position = "auto", scale = 1 })

-- Dell Alienware 25" next to it, pinned to 1 like the Samsung (it used to
-- follow the laptop's omarchy_monitor_scale through the catch-all rule).
hl.monitor({ output = "desc:Dell Inc. AW2521HFA", mode = "preferred", position = "auto", scale = 1 })

-- Samsung 32" 4K stands left of the laptop, with its own scale of 1.5
-- (2560x1440 logical; was 1.6).
hl.monitor({ output = "desc:Samsung Electric Company LF32TU87", mode = "preferred", position = "auto-left", scale = 1.5 })
