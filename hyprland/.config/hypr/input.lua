-- The keyboard, mouse and touchpad, and the touchpad's gestures. Loaded by hyprland.lua,
-- before your personal/input.lua.

local keyboard = __require("keyboard_state")              -- Keyboard layout, reloaded when you switch it
local mouse = __require("lib.state").fresh("input_state") -- The settings' mouse and touchpad

-----------
-- INPUT --
-----------

hl.config({
  input = {
    kb_layout = keyboard.xkb,
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",

    follow_mouse = mouse.focus and 1 or 0, -- Focus follows the mouse, or waits for a click

    sensitivity = mouse.sensitivity,       -- From -1.0 to 1.0, 0 leaves the mouse as it is
    accel_profile = mouse.acceleration,
    natural_scroll = mouse.mouse_natural,

    touchpad = {
      natural_scroll = mouse.touchpad_natural,
      tap_to_click = mouse.touchpad_tap,
      disable_while_typing = mouse.touchpad_typing,
      scroll_factor = mouse.touchpad_scroll,
    },
  },
})

-- The touchpads on or off, as the toggle left them (see touchpad_state.lua)
local state = __require("lib.state").fresh("touchpad_state")

for _, device in ipairs(state.devices) do
  hl.device({
    name = device,
    enabled = state.enabled,
  })
end

--------------
-- GESTURES --
--------------

-- Three fingers sideways to change workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Four fingers to drag a window around
hl.gesture({ fingers = 4, direction = "swipe", action = "move" })
