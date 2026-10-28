-- Reads what the shell saves in ~/.local/state/hyprpunk, for the *_state.lua files.
-- They load it with __require, the plain Lua one, since it's a helper rather than config.

local state = {}

state.dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/hyprpunk"

-- The first line of a state file, or the fallback while the shell hasn't written it yet
function state.line(name, fallback)
  local file = io.open(state.dir .. "/" .. name, "r")
  if file == nil then
    return fallback
  end

  local value = file:read("*l")
  file:close()
  return value or fallback
end

-- Every key=value line of a state file, in order, or nil if there's no file yet
function state.pairs(name)
  local file = io.open(state.dir .. "/" .. name, "r")
  if file == nil then
    return nil
  end

  local entries = {}
  for line in file:lines() do
    local key, value = line:match("^([%w%._-]+)=(.+)$")
    if key ~= nil then
      table.insert(entries, { key = key, value = value })
    end
  end

  file:close()
  return entries
end

-- A state module read again from disk, so a reload picks up what the shell just saved
-- (plain Lua modules stay cached otherwise)
function state.fresh(module)
  package.loaded[module] = nil
  return __require(module)
end

return state
