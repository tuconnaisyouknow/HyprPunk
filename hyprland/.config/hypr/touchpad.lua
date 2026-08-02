package.loaded["touchpad_state"] = nil
local state = __require("touchpad_state")

for _, device in ipairs(state.devices) do
  hl.device({
    name = device,
    enabled = state.enabled,
  })
end
