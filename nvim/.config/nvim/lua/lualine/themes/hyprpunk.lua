-- lualine's colors for the hyprpunk colorscheme, which lualine picks by its name and
-- takes again whenever the palette changes. Normal mode in the accent; the others in
-- the palette's tones, as the prompt shows Vim's modes.
local c = require("hyprpunk.palette").current

local function mode(color)
  return {
    a = { fg = c.surface, bg = color, gui = "bold" },
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
    a = { fg = c.overlay1, bg = "NONE" },
    b = { fg = c.overlay1, bg = "NONE" },
    c = { fg = c.overlay1, bg = "NONE" },
  },
}
