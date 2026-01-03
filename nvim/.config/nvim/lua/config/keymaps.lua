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

-- Window navigation (splits) - jklm
vim.keymap.set('n', '<C-j>', '<C-w>h', { silent = true, desc = 'Window left' })
vim.keymap.set('n', '<C-k>', '<C-w>j', { silent = true, desc = 'Window down' })
vim.keymap.set('n', '<C-l>', '<C-w>k', { silent = true, desc = 'Window up' })
vim.keymap.set('n', '<C-m>', '<C-w>l', { silent = true, desc = 'Window right' })
