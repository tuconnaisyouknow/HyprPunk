local layouts = {
  fr = {
    name = "fr", left = "j", down = "k", up = "l", right = "m", extra = "h",
    pane_left = "<NL>", pane_down = "<C-k>", pane_up = "<C-l>", pane_right = "<F12>",
  },
  us = {
    name = "us", left = "h", down = "j", up = "k", right = "l", extra = "m",
    pane_left = "<C-h>", pane_down = "<C-j>", pane_up = "<C-k>", pane_right = "<C-l>",
  },
}

local state_home = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local state_file = io.open(state_home .. "/hyprpunk/keyboard-layout", "r")
local name = state_file and state_file:read("*l") or "us"

if state_file then
  state_file:close()
end

return layouts[name] or layouts.us
