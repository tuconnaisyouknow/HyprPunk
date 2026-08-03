-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function apply_keyboard_layout()
  package.loaded['config.keyboard'] = nil
  local keyboard = require('config.keyboard')

  for _, key in ipairs({ 'h', 'j', 'k', 'l', 'm' }) do
    pcall(vim.keymap.del, 'n', key)
    pcall(vim.keymap.del, 'v', key)
  end

  if keyboard.name == 'fr' then
    vim.keymap.set('n', keyboard.left, 'h', { silent = true, desc = "Left" })
    vim.keymap.set('n', keyboard.down, 'j', { silent = true, desc = "Down" })
    vim.keymap.set('n', keyboard.up, 'k', { silent = true, desc = "Up" })
    vim.keymap.set('n', keyboard.right, 'l', { silent = true, desc = "Right" })
    vim.keymap.set('n', keyboard.extra, 'm', { silent = true, desc = "Mark" })

    vim.keymap.set('v', keyboard.left, 'h', { silent = true, desc = "Left" })
    vim.keymap.set('v', keyboard.down, 'j', { silent = true, desc = "Down" })
    vim.keymap.set('v', keyboard.up, 'k', { silent = true, desc = "Up" })
    vim.keymap.set('v', keyboard.right, 'l', { silent = true, desc = "Right" })
  end

  for _, key in ipairs({ '<C-h>', '<C-j>', '<C-k>', '<C-l>', '<F12>' }) do
    pcall(vim.keymap.del, 'n', key)
  end
  vim.keymap.set('n', keyboard.pane_left, ':TmuxNavigateLeft<CR>',
    { silent = true, desc = "Switch to left window" })
  vim.keymap.set('n', keyboard.pane_down, ':TmuxNavigateDown<CR>',
    { silent = true, desc = "Switch to lower window" })
  vim.keymap.set('n', keyboard.pane_up, ':TmuxNavigateUp<CR>',
    { silent = true, desc = "Switch to upper window" })
  vim.keymap.set('n', keyboard.pane_right, ':TmuxNavigateRight<CR>',
    { silent = true, desc = "Switch to right window" })
end

apply_keyboard_layout()
vim.api.nvim_create_user_command('KeyboardLayoutReload', apply_keyboard_layout,
  { desc = 'Reload the active keyboard layout' })

-- Use system clipboard for yank operations
vim.keymap.set('n', 'y', '"+y', { silent = true, desc = "Yank" })
vim.keymap.set('v', 'y', '"+y', { silent = true, desc = "Yank" })
vim.keymap.set('n', 'Y', '"+Y', { silent = true, desc = "Yank the line" })
vim.keymap.set('n', 'yy', '"+yy', { silent = true, desc = "Yank the line" })

vim.keymap.set('n', '<leader>dd', '"+dd', { silent = true, desc = "Delete the line -> clipboard" })
vim.keymap.set('v', '<leader>d', '"+d', { silent = true, desc = "Delete the selection -> clipboard" })

-- New line without entering insert mode
vim.keymap.set('n', '<leader>o', ":put =''<CR>",
  { silent = true, desc = "New line before without insert" })
vim.keymap.set('n', '<leader>O', ":put! =''<CR>",
  { silent = true, desc = "New line after without insert" })

vim.api.nvim_set_keymap('n', '<C-\\>', ':TmuxNavigatePrevious<CR>',
  { noremap = true, silent = true, desc = "Switch to previous window" })
