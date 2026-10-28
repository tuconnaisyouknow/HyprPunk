--------------
-- TOUCHPAD --
--------------

-- Turns the touchpads on or off as the toggle left them (see touchpad_state.lua)
package.loaded["touchpad_state"] = nil
local state = __require("touchpad_state")

for _, device in ipairs(state.devices) do
  hl.device({
    name = device,
    enabled = state.enabled,
  })
end
