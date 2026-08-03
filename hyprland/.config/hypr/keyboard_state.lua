local layouts = {
  fr = { name = "fr", xkb = "fr", left = "j", down = "k", up = "l", right = "m" },
  us = { name = "us", xkb = "us", left = "h", down = "j", up = "k", right = "l" },
}

local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local state_file = io.open(state_home .. "/hyprpunk/keyboard-layout", "r")
local name = state_file and state_file:read("*l") or "us"

if state_file then
  state_file:close()
end

return layouts[name] or layouts.us
