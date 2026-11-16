-- The wallpaper's accent on the window you're in: its border and its glow. Loaded by
-- hyprland.lua, and run again by wallpaperctl.sh for every new palette, which
-- recolors them without reloading Hyprland: a reload freezes every screen for a few
-- frames, in the middle of the wallpaper's transition.
local state = __require("lib.state")

-- Catppuccin Mocha's mauve, until the first palette is written
local accent = "cba6f7"
for _, entry in ipairs(state.pairs("hypr-colors") or {}) do
  if entry.key == "primary" then
    accent = entry.value
  end
end

hl.config({
  -- A thin line marks the window you're in, the others have none
  general = { col = { active_border = "rgba(" .. accent .. "b3)" } },
  -- A faint glow around it, nothing around the others
  decoration = { shadow = { color = "rgba(" .. accent .. "26)" } },
})
