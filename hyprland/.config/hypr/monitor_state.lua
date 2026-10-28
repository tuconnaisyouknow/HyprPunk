-- Reads what the display settings saved in ~/.local/state/hyprpunk/monitor-state.conf.
-- Without that file, every screen is left to Hyprland's automatic setup.
local state = {
  default_mode = nil,
  default_scale = "auto",
  layout = "auto",
  selectors = {},
  modes = {},
  scales = {},
  positions = {},
  slots = {},
  workspaces = {},
  monitors = {},
}

local entries = __require("lib.state").pairs("monitor-state.conf")
if entries == nil then
  return state
end

-- One key=value per line, with the screen's name after the dot (mode.DP-1=...)
for _, entry in ipairs(entries) do
  local key, value = entry.key, entry.value
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
  elseif key and key:match("^slot%.") then
    state.slots[key:sub(6)] = tonumber(value)
  elseif key and key:match("^workspaces%.") then
    local monitor = key:sub(12)
    state.workspaces[monitor] = {}
    for workspace in value:gmatch("[^,]+") do
      local number = tonumber(workspace)
      if number ~= nil then
        table.insert(state.workspaces[monitor], number)
      end
    end
  end
end

return state
