--------------
-- MONITORS --
--------------

-- monitor_state is a plain Lua table, so it goes through the original require
-- (Hyprland's own one is for config files). Its cache is cleared so a reload
-- picks up whatever the display settings just saved.
package.loaded["monitor_state"] = nil
local state = __require("monitor_state")

-- Any screen we know nothing about yet gets sensible defaults
hl.monitor({
  output = "",
  mode = state.default_mode or "preferred",
  position = "auto",
  scale = state.default_scale or "auto",
})

-- The saved ones get their own mode, scale and, in a custom layout, position
for _, monitor in ipairs(state.monitors) do
  hl.monitor({
    output = state.selectors[monitor],
    mode = state.modes[monitor] or state.default_mode or "preferred",
    position = state.layout == "custom" and (state.positions[monitor] or "auto-right") or "auto-right",
    scale = state.scales[monitor] or state.default_scale or "auto",
  })
end
