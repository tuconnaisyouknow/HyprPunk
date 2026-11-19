-- Reads which windows are see-through, saved by transparencyctl.sh: all of them, the
-- terminal alone or none. No file yet means the terminal alone.
local state = __require("lib.state")

local which = state.line("transparency", "terminal")
-- Slight, so the wallpaper shows behind the blur while the text stays easy to read
local see_through = 0.9

return {
  -- Every window's opacity
  windows = which == "all" and see_through or 1,
  -- The terminal's own, when it's the only one see-through
  terminal = which ~= "all" and which ~= "none" and see_through or nil,
}
