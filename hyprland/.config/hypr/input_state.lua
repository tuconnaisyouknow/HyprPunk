-- Reads how the mouse and the touchpad behave, saved by inputctl.sh from the shell's
-- settings. Missing keys keep HyprPunk's defaults, the same as the script's.
local state = __require("lib.state")

local input = {
  sensitivity = 0,
  acceleration = "adaptive",
  focus = true,
  mouse_natural = false,
  touchpad_natural = false,
  touchpad_tap = true,
  touchpad_typing = true,
  touchpad_scroll = 1,
}

local numbers = { sensitivity = true, ["touchpad.scroll"] = true }

for _, entry in ipairs(state.pairs("input.conf") or {}) do
  local key = entry.key:gsub("%.", "_")
  if input[key] ~= nil then
    if numbers[entry.key] then
      input[key] = tonumber(entry.value) or input[key]
    elseif type(input[key]) == "boolean" then
      input[key] = entry.value == "true"
    else
      input[key] = entry.value
    end
  end
end

return input
