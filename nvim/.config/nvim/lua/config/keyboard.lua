-- Where the Vim keys sit, chosen from the shell and worked out by keyboard-layoutctl.sh:
-- on Vim's own letters, or on the home row (j k l m on AZERTY). A letter the move left
-- free takes over what the key the arrows landed on did (h sets marks on AZERTY).
-- Ctrl + a key the terminal has no code for arrives as a function key, sent by kitty.
local keyboard = {
  left = "h",
  down = "j",
  up = "k",
  right = "l",
  -- { key, what it does now }, for the letters left free
  spare = {},
}
local pane = { left = "h", down = "j", up = "k", right = "l" }

local state_home = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local state_file = io.open(state_home .. "/hyprpunk/keyboard/keys", "r")

-- Vim's letters until something else has been picked
if state_file then
  for line in state_file:lines() do
    local name, value = line:match("^([%w_]+)=(.+)$")
    if keyboard[name] ~= nil and name ~= "spare" then
      keyboard[name] = value
    elseif name and name:match("^ctrl_") then
      pane[name:sub(6)] = value
    elseif name and name:match("^spare_") then
      table.insert(keyboard.spare, { name:sub(7), value })
    end
  end
  state_file:close()
end

-- A key as a mapping writes it
function keyboard.lhs(key)
  return (key:gsub("<", "<lt>"):gsub("\\", "<Bslash>"):gsub("|", "<Bar>"))
end

for direction, key in pairs(pane) do
  keyboard["pane_" .. direction] = key:match("^F%d+$") and ("<" .. key .. ">") or ("<C-" .. key .. ">")
end

-- The key that now does what one of Vim's did
function keyboard.key(role)
  for _, pair in ipairs(keyboard.spare) do
    if pair[2] == role then
      return pair[1]
    end
  end
  return role
end

return keyboard
