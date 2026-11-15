-- Reads what the display settings saved in ~/.local/state/hyprpunk/monitor-state.conf.
-- Without that file, every screen is left to Hyprland's automatic setup.
local state = {
  layout = "auto",
  selectors = {},
  modes = {},
  scales = {},
  positions = {},
  workspaces = {},
  monitors = {},
}

local entries = __require("lib.state").pairs("monitor-state.conf")
if entries == nil then
  return state
end

-- One key=value per line, with the screen's ID after the dot (mode.fe3c08c2c010f02a=...)
for _, entry in ipairs(entries) do
  local key, value = entry.key, entry.value
  if key == "layout" then
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
