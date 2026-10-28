-- Reads the shell's glass style saved by glassctl.sh. The liquid glass is more
-- see-through, so the layers' blur has to reach fainter pixels for it to show.
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local state_file = io.open(state_home .. "/hyprpunk/glass-style", "r")
local style = state_file and state_file:read("*l") or "classic"

if state_file then
  state_file:close()
end

local liquid = style == "liquid"

return {
  liquid = liquid,
  -- How opaque a pixel must be to get blurred behind
  ignore_alpha = liquid and 0.2 or 0.5,
}
