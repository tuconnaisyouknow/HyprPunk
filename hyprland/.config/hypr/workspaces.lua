package.loaded["monitor_state"] = nil
local state = __require("monitor_state")

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

table.sort(assignments, function(left, right)
  return left.workspace < right.workspace
end)

for _, assignment in ipairs(assignments) do
  hl.workspace_rule({
    workspace = tostring(assignment.workspace),
    monitor = assignment.monitor,
  })
end
