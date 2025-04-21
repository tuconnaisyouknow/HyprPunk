-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 📦 Déplacement personnalisé en mode normal (jklm → hjkl)
map("n", "j", "h", opts) -- Gauche
map("n", "k", "j", opts) -- Bas
map("n", "l", "k", opts) -- Haut
map("n", "m", "l", opts) -- Droite

-- 📦 Déplacement personnalisé en mode visuel
map("v", "j", "h", opts)
map("v", "k", "j", opts)
map("v", "l", "k", opts)
map("v", "m", "l", opts)

-- 🏷️ Déplacement de la fonction "mark" de `m` vers `,`
map("n", ",", "m", opts)

-- Inverser les marks : ` devient ' et vice versa
map("n", "`", "'", opts) -- ` saute à la ligne (comportement original de ')
map("n", "'", "`", opts) -- ' saute à la position exacte (comportement original de `)

map({ "n", "v" }, "y", '"+y', opts)
map("n", "Y", '"+Y', opts)
map("n", "yy", '"+yy', opts)
map("v", "Y", '"+y', opts)
