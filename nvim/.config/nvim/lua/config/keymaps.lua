-- On top of LazyVim's keymaps:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

---------------------
-- KEYBOARD LAYOUT --
---------------------

-- Moves and pane switching follow where the Vim keys sit (see keyboard.lua).
-- :KeyboardLayoutReload runs it again when you switch, no need to restart Neovim.
local applied = {}

local function apply_keyboard_layout()
  package.loaded['config.keyboard'] = nil
  local keyboard = require('config.keyboard')

  for _, mapping in ipairs(applied) do
    pcall(vim.keymap.del, mapping[1], mapping[2])
  end
  applied = {}
  for _, key in ipairs({ 'h', 'j', 'k', 'l' }) do
    pcall(vim.keymap.del, 'n', key)
    pcall(vim.keymap.del, 'v', key)
  end

  local function map(mode, key, action, description)
    vim.keymap.set(mode, key, action, { silent = true, desc = description })
    table.insert(applied, { mode, key })
  end

  -- Each key does what the letter of Vim's it replaces did, and nothing when it's the same
  local moves = {
    { keyboard.left,  'h', "Left" },
    { keyboard.down,  'j', "Down" },
    { keyboard.up,    'k', "Up" },
    { keyboard.right, 'l', "Right" },
  }
  for _, spare in ipairs(keyboard.spare) do
    table.insert(moves, { spare[1], spare[2], "What " .. spare[2] .. " did" })
  end
  for _, move in ipairs(moves) do
    if move[1] ~= move[2] then
      map('n', keyboard.lhs(move[1]), keyboard.lhs(move[2]), move[3])
      map('v', keyboard.lhs(move[1]), keyboard.lhs(move[2]), move[3])
    end
  end

  -- Ctrl + the arrows moves between Neovim splits and tmux panes alike
  map('n', keyboard.pane_left, ':TmuxNavigateLeft<CR>', "Switch to left window")
  map('n', keyboard.pane_down, ':TmuxNavigateDown<CR>', "Switch to lower window")
  map('n', keyboard.pane_up, ':TmuxNavigateUp<CR>', "Switch to upper window")
  map('n', keyboard.pane_right, ':TmuxNavigateRight<CR>', "Switch to right window")
end

apply_keyboard_layout()
vim.api.nvim_create_user_command('KeyboardLayoutReload', apply_keyboard_layout,
  { desc = 'Reload where the Vim keys sit' })

-- Ctrl+\ goes back to the last pane, whatever the layout
vim.api.nvim_set_keymap('n', '<C-\\>', ':TmuxNavigatePrevious<CR>',
  { noremap = true, silent = true, desc = "Switch to previous window" })

---------------
-- CLIPBOARD --
---------------

-- Yanks go to the system clipboard, deletes only when you ask with the leader
vim.keymap.set('n', 'y', '"+y', { silent = true, desc = "Yank" })
vim.keymap.set('v', 'y', '"+y', { silent = true, desc = "Yank" })
vim.keymap.set('n', 'Y', '"+Y', { silent = true, desc = "Yank the line" })
vim.keymap.set('n', 'yy', '"+yy', { silent = true, desc = "Yank the line" })

vim.keymap.set('n', '<leader>dd', '"+dd', { silent = true, desc = "Delete the line -> clipboard" })
vim.keymap.set('v', '<leader>d', '"+d', { silent = true, desc = "Delete the selection -> clipboard" })

-----------
-- LINES --
-----------

-- Add an empty line and stay in normal mode
vim.keymap.set('n', '<leader>o', ":put =''<CR>",
  { silent = true, desc = "New line below without insert" })
vim.keymap.set('n', '<leader>O', ":put! =''<CR>",
  { silent = true, desc = "New line above without insert" })
