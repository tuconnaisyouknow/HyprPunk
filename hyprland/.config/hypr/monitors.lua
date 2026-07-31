-- ################
-- ### MONITORS ###
-- ################

-- Hyprland wraps `require` to isolate configuration files. monitor_state is a
-- regular Lua module returning a table, so it must use the original loader.
-- Clear its cache because monitor-state.conf can change between config reloads.
package.loaded["monitor_state"] = nil
local state = __require("monitor_state")

-- Catch new displays and provide the complete automatic configuration when no
-- output-specific state has been saved yet.
hl.monitor({
  output = "",
  mode = state.default_mode or "preferred",
  position = "auto",
  scale = state.default_scale or "auto",
})

for _, monitor in ipairs(state.monitors) do
  hl.monitor({
    output = state.selectors[monitor],
    mode = state.modes[monitor] or state.default_mode or "preferred",
    position = state.layout == "custom" and (state.positions[monitor] or "auto-right") or "auto-right",
    scale = state.scales[monitor] or state.default_scale or "auto",
  })
end
