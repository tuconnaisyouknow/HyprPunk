-- The wallpaper's accent on the window you're in: its border and, in neon, its glow.
-- Loaded by hyprland.lua, and run again by wallpaperctl.sh for every new palette, which
-- recolors them without reloading Hyprland: a reload freezes every screen for a few
-- frames, in the middle of the wallpaper's transition.
local state = __require("lib.state")

-- HyprPunk's default accent in neon, until the first palette is written
local look = { primary = "cba6f7", theme = "neon" }
for _, entry in ipairs(state.pairs("hypr-colors") or {}) do
  look[entry.key] = entry.value
end

hl.config({
  -- A thin line marks the window you're in, the others have none
  general = { col = { active_border = "rgba(" .. look.primary .. "b3)" } },
  -- Neon emits its light: a faint glow around that window, nothing around the others.
  -- Daydream receives it, so no window glows.
  decoration = {
    shadow = {
      enabled = look.theme == "neon",
      color = "rgba(" .. look.primary .. "26)",
    },
  },
})
