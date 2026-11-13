-- Reads the apps chosen in the shell's settings, saved by appsctl.sh: the command that
-- starts each one, by its role (terminal, browser, files, music).
local state = __require("lib.state")

local apps = {}

for _, entry in ipairs(state.pairs("apps.conf") or {}) do
  apps[entry.key] = entry.value
end

return apps
