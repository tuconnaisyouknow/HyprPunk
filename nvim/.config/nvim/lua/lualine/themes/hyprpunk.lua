-- lualine's colors for the hyprpunk colorscheme, which lualine picks by its name and
-- takes again whenever the palette changes. Normal mode in the accent, the others in
-- the palette's tones, as the prompt and yazi show them. The windows you're not in read
-- the secondary at half.
local c = require("hyprpunk.palette").current
local off = require("hyprpunk.theme").blend(c.secondary, c.surface, 0.5)

local function mode(color)
  return {
    a = { fg = c.on_primary, bg = color, gui = "bold" },
    b = { fg = color, bg = c.surface_container },
    c = { fg = c.secondary, bg = "NONE" },
  }
end

return {
  normal = mode(c.primary),
  insert = mode(c.tone_green),
  visual = mode(c.tone_blue),
  replace = mode(c.tone_red),
  command = mode(c.tone_orange),
  terminal = mode(c.tone_teal),
  inactive = {
    a = { fg = off, bg = "NONE" },
    b = { fg = off, bg = "NONE" },
    c = { fg = off, bg = "NONE" },
  },
}
