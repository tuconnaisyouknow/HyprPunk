-- hl.bind with a mandatory description, remembered so the shell's keybindings panel
-- can list every binding and run one when you click it (hyprctl eval run_keybinding(...)).
-- keybindings.lua and your personal/keybindings.lua both go through it.

local binds = {}

local actions = {}
-- Which descriptions each key combination holds, to forget them when it's unbound
local descriptionsByKeys = {}

-- Global, since that's what hyprctl eval can reach
function run_keybinding(description)
  local action = actions[description]
  assert(action ~= nil, "unknown keybinding: " .. description)

  if type(action) == "function" then
    action()
  else
    hl.dispatch(action)
  end
end

-- Like hl.bind, but a description is mandatory: it's what the panel shows
function binds.bind(keys, dispatcher, description, opts)
  assert(type(description) == "string" and description ~= "", "keybinding description is required")
  actions[description] = dispatcher
  descriptionsByKeys[keys] = descriptionsByKeys[keys] or {}
  table.insert(descriptionsByKeys[keys], description)
  opts = opts or {}
  opts.description = description
  return hl.bind(keys, dispatcher, opts)
end

-- Frees a key combination, written the same way it was bound ("SUPER + P")
function binds.unbind(keys)
  hl.unbind(keys)
  for _, description in ipairs(descriptionsByKeys[keys] or {}) do
    actions[description] = nil
  end
  descriptionsByKeys[keys] = nil
end

-- Gives a key combination a new action, instead of stacking a second one on it
function binds.rebind(keys, dispatcher, description, opts)
  binds.unbind(keys)
  return binds.bind(keys, dispatcher, description, opts)
end

return binds
