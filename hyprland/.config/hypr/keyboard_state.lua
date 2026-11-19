-- The keyboard layout and where the Vim keys sit, chosen from the shell
-- (keyboard-layoutctl.sh). On Vim's letters the arrows are bound by name, wherever the
-- layout puts h j k l. On the home row they're bound by position: the key under your
-- right index and the three to its right, whatever the layout writes there.
local state = __require("lib.state")

local function read(name)
  local values = {}
  for _, entry in ipairs(state.pairs(name) or {}) do
    values[entry.key] = entry.value
  end
  return values
end

-- US on Vim's letters until something else has been picked
local chosen = read("keyboard-layout")
local keyboard = { layout = chosen.layout or "us", variant = chosen.variant or "" }

if chosen.keys == "home" then
  keyboard.left, keyboard.down, keyboard.up, keyboard.right = "code:44", "code:45", "code:46", "code:47"
else
  keyboard.left, keyboard.down, keyboard.up, keyboard.right = "h", "j", "k", "l"
end

-- The keys the arrows landed on, each with the letter of Vim's it left free
local worked_out = read("keyboard/keys")
local moved = {}
for _, free in ipairs({ "h", "j", "k", "l" }) do
  for _, arrow in ipairs({ "left", "down", "up", "right" }) do
    if worked_out["spare_" .. free] ~= nil and worked_out["spare_" .. free] == worked_out[arrow] then
      moved[worked_out["name_" .. arrow]:lower()] = free:upper()
    end
  end
end

-- The modifiers the arrows are bound with, in alphabetical order
local with_arrows = { ["SUPER"] = true, ["SHIFT+SUPER"] = true, ["CTRL+SHIFT+SUPER"] = true }

-- A shortcut the arrows landed on (Super+T on Dvorak's home row) moves to the letter
-- they left free. Takes and gives the keys as hl.bind reads them ("SUPER + T").
function keyboard.beside_arrows(keys)
  local modifiers, key = keys:match("^(.*) %+ ([^+ ]+)$")
  if key == nil or moved[key:lower()] == nil then
    return keys
  end

  local names = {}
  for name in modifiers:gmatch("[^+ ]+") do
    table.insert(names, name)
  end
  table.sort(names)
  if not with_arrows[table.concat(names, "+")] then
    return keys
  end

  return modifiers .. " + " .. moved[key:lower()]
end

return keyboard
