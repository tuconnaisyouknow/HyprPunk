-- hl.bind with a mandatory description, remembered so the shell's keybindings panel
-- can list every binding and run one when you click it (hyprctl eval run_keybinding(...)).

local binds = {}

local actions = {}

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
  opts = opts or {}
  opts.description = description
  return hl.bind(keys, dispatcher, opts)
end

return binds
