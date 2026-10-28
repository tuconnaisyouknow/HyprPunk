-- Reads the touchpad toggle saved by touchpadctl.sh: on or off, and which devices it covers.
-- No file yet means touchpads stay on.
local state = __require("lib.state")

local touchpad = {
  enabled = true,
  devices = {},
}

for _, entry in ipairs(state.pairs("touchpad-state.conf") or {}) do
  if entry.key == "enabled" then
    touchpad.enabled = entry.value == "true"
  elseif entry.key == "device" then
    table.insert(touchpad.devices, entry.value)
  end
end

return touchpad
