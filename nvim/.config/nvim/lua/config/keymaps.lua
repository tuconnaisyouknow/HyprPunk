-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Custom movement in normal mode (jklm → hjkl)
vim.keymap.set('n', 'j', 'h', { silent = true, desc = "Left" })
vim.keymap.set('n', 'k', 'j', { silent = true, desc = "Down" })
vim.keymap.set('n', 'l', 'k', { silent = true, desc = "Up" })
vim.keymap.set('n', 'm', 'l', { silent = true, desc = "Right" })

-- Custom movement in visual mode
vim.keymap.set('v', 'j', 'h', { silent = true, desc = "Left" })
vim.keymap.set('v', 'k', 'j', { silent = true, desc = "Down" })
vim.keymap.set('v', 'l', 'k', { silent = true, desc = "Up" })
vim.keymap.set('v', 'm', 'l', { silent = true, desc = "Right" })

-- Move the "mark" function from `m` to `h`
vim.keymap.set('n', 'h', 'm', { silent = true, desc = "Mark" })

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

-- Deleting window navigation keybindings
vim.keymap.del('n', '<C-h>')
vim.keymap.del('n', '<C-j>')
vim.keymap.del('n', '<C-k>')
vim.keymap.del('n', '<C-l>')

-- Vim tmux navigator config
vim.api.nvim_set_keymap('n', '<NL>', ':TmuxNavigateLeft<CR>',
  { noremap = true, silent = true, desc = "Switch to left window" })
vim.api.nvim_set_keymap('n', '<C-k>', ':TmuxNavigateDown<CR>',
  { noremap = true, silent = true, desc = "Switch to lower window" })
vim.api.nvim_set_keymap('n', '<C-l>', ':TmuxNavigateUp<CR>',
  { noremap = true, silent = true, desc = "Switch to upper window" })
vim.api.nvim_set_keymap('n', '<F12>', ':TmuxNavigateRight<CR>',
  { noremap = true, silent = true, desc = "Switch to right window" })
vim.api.nvim_set_keymap('n', '<C-\\>', ':TmuxNavigatePrevious<CR>',
  { noremap = true, silent = true, desc = "Switch to previous window" })
