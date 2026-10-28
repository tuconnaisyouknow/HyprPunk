-- Pins workspaces to screens, as the shell's display settings chose. Loaded by hyprland.lua.

----------------
-- WORKSPACES --
----------------

-- Pins each workspace to the screen it was given in the display settings
local state = __require("lib.state").fresh("monitor_state")

local assignments = {}

for monitor, workspaces in pairs(state.workspaces) do
  local selector = state.selectors[monitor]
  if selector ~= nil then
    for _, workspace in ipairs(workspaces) do
      table.insert(assignments, {
        workspace = workspace,
        monitor = selector,
      })
    end
  end
end

-- Sorted so the rules always come out in the same order, 1 to 10
table.sort(assignments, function(left, right)
  return left.workspace < right.workspace
end)

for _, assignment in ipairs(assignments) do
  hl.workspace_rule({
    workspace = tostring(assignment.workspace),
    monitor = assignment.monitor,
  })
end
