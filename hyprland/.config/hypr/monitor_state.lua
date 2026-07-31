local state = {
  default_mode = nil,
  default_scale = "auto",
  layout = "auto",
  selectors = {},
  modes = {},
  scales = {},
  positions = {},
  monitors = {},
}

local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local state_path = state_home .. "/hyprpunk/monitor-state.conf"
local state_file = io.open(state_path, "r")

if state_file == nil then
  return state
end

for line in state_file:lines() do
  local key, value = line:match("^([%w%._-]+)=(.+)$")
  if key == "default_mode" then
    state.default_mode = value
  elseif key == "default_scale" then
    state.default_scale = value
  elseif key == "layout" then
    state.layout = value
  elseif key and key:match("^selector%.") then
    local monitor = key:sub(10)
    if state.selectors[monitor] == nil then
      table.insert(state.monitors, monitor)
    end
    state.selectors[monitor] = value
  elseif key and key:match("^mode%.") then
    state.modes[key:sub(6)] = value
  elseif key and key:match("^scale%.") then
    state.scales[key:sub(7)] = value
  elseif key and key:match("^position%.") then
    state.positions[key:sub(10)] = value
  end
end

state_file:close()
return state
