local state = {
  enabled = true,
  devices = {},
}

local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local state_path = state_home .. "/hyprpunk/touchpad-state.conf"
local state_file = io.open(state_path, "r")

if state_file == nil then
  return state
end

for line in state_file:lines() do
  local key, value = line:match("^([%w_-]+)=(.+)$")
  if key == "enabled" then
    state.enabled = value == "true"
  elseif key == "device" then
    table.insert(state.devices, value)
  end
end

state_file:close()
return state
