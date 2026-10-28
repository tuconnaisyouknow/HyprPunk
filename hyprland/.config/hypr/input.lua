-- The keyboard, mouse and touchpad, and the touchpad's gestures. Loaded by hyprland.lua.

local keyboard = __require("keyboard_state") -- Keyboard layout, reloaded when you switch it

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

    follow_mouse = 1, -- Focus follows the mouse

    sensitivity = 0,  -- From -1.0 to 1.0, 0 leaves the mouse as it is

    touchpad = {
      natural_scroll = false,
      disable_while_typing = true,
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
