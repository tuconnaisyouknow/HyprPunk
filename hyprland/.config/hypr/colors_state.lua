-- Reads the wallpaper palette's accent, which matugen writes for every new wallpaper,
-- as bare hex so you add your own alpha ("rgba(" .. colors.primary .. "b3)").
local state = __require("lib.state")

-- Catppuccin Mocha's mauve, until the first palette is written
local colors = { primary = "cba6f7" }
for _, entry in ipairs(state.pairs("hypr-colors") or {}) do
  colors[entry.key] = entry.value
end

return colors
