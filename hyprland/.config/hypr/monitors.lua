-- Each screen's mode, scale and position, as the shell's display settings saved them.
-- Loaded by hyprland.lua.

--------------
-- MONITORS --
--------------

local state = __require("monitor_state")

-- Any screen we know nothing about yet gets sensible defaults
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})

-- The saved ones get their own mode, scale and, in a custom layout, position
for _, monitor in ipairs(state.monitors) do
  hl.monitor({
    output = state.selectors[monitor],
    mode = state.modes[monitor] or "preferred",
    position = state.layout == "custom" and (state.positions[monitor] or "auto-right") or "auto-right",
    scale = state.scales[monitor] or "auto",
  })
end
