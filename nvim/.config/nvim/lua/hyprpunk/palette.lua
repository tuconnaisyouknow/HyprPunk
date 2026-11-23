-- The wallpaper's palette for the hyprpunk colorscheme. matugen writes it on every new
-- wallpaper; until the first one, Neovim takes the shell's own defaults. Open Neovims
-- watch the file and draw themselves again when it changes.
local M = {}

local path = (vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")) .. "/hyprpunk/nvim-colors.lua"

-- The same colors the shell starts from, before any wallpaper
M.defaults = {
  primary = "#cba6f7",
  on_primary = "#11111b",
  secondary = "#b4befe",
  text = "#cdd6f4",
  subtext1 = "#bac2de",
  subtext0 = "#a6adc8",
  overlay2 = "#9399b2",
  overlay1 = "#7f849c",
  overlay0 = "#6c7086",
  surface_container_highest = "#585b70",
  surface_container_high = "#45475a",
  surface_container = "#313244",
  surface = "#1e1e2e",
  surface_container_low = "#181825",
  surface_container_lowest = "#11111b",
  tone_red = "#f38ba8",
  tone_orange = "#fab387",
  tone_yellow = "#f9e2af",
  tone_green = "#a6e3a1",
  tone_teal = "#94e2d5",
  tone_cyan = "#89dceb",
  tone_blue = "#89b4fa",
  tone_pink = "#f5c2e7",
  error = "#f38ba8",
  green = "#a6e3a1",
  yellow = "#f9e2af",
  blue = "#89b4fa",
}

-- The file as written and its colors: the defaults while there's none, nothing while
-- matugen is still writing it, since it empties the file first
local function read()
  local file = io.open(path)
  if not file then
    return "", M.defaults
  end
  local text = file:read("a")
  file:close()
  local ok, colors = pcall(function()
    return assert(load(text))()
  end)
  return text, ok and type(colors) == "table" and vim.tbl_extend("keep", colors, M.defaults) or nil
end

local shown
M.current = M.defaults

-- The palette to draw with: the file's, or the last whole one while it's being written
function M.load()
  local text, colors = read()
  if colors then
    shown, M.current = text, colors
  end
  return M.current
end

-- The folder is watched, since the file may not exist yet. matugen empties the file then
-- writes it, which fires more than once: a palette is drawn once whole and new, and only
-- while the hyprpunk colorscheme is the one on screen
local watching = false
function M.watch()
  if watching then
    return
  end
  watching = true
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.uv.new_fs_event():start(vim.fs.dirname(path), {}, vim.schedule_wrap(function(_, name)
    if name ~= vim.fs.basename(path) or vim.g.colors_name ~= "hyprpunk" then
      return
    end
    local text, colors = read()
    if colors and text ~= shown then
      vim.cmd.colorscheme("hyprpunk")
    end
  end))
end

return M
