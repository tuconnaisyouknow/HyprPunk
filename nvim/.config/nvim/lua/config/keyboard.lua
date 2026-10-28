-- The keyboard layout chosen from the shell. hjkl move to jklm on AZERTY so they stay
-- under the right hand, m (marks) takes h's place, and the pane keys follow.
-- Terminals send Ctrl+J as <NL> and Ctrl+M as Enter, so kitty turns Ctrl+M into F12.
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

-- US until something else has been picked
local state_home = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local state_file = io.open(state_home .. "/hyprpunk/keyboard-layout", "r")
local name = state_file and state_file:read("*l") or "us"

if state_file then
  state_file:close()
end

return layouts[name] or layouts.us
