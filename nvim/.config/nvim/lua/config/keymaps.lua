-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 📦 Custom movement in normal mode (jklm → hjkl)
map("n", "j", "h", opts) -- Gauche
map("n", "k", "j", opts) -- Bas
map("n", "l", "k", opts) -- Haut
map("n", "m", "l", opts) -- Droite

-- 📦 Custom movement in visual mode
map("v", "j", "h", opts)
map("v", "k", "j", opts)
map("v", "l", "k", opts)
map("v", "m", "l", opts)

-- 🏷️ Move the "mark" function from `m` to `,`
map("n", ",", "m", opts)

-- Swap marks: ` becomes ' and vice versa
map("n", "`", "'", opts) -- ` jumps to the line (original behavior of ')
map("n", "'", "`", opts) -- ' jumps to the exact position (original behavior of `)

-- Use system clipboard for yank operations
map({ "n", "v" }, "y", '"+y', opts)
map("n", "Y", '"+Y', opts)
map("n", "yy", '"+yy', opts)
map("v", "Y", '"+y', opts)
