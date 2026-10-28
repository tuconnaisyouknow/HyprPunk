-- On top of LazyVim's defaults:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Keep the system clipboard apart: only yanks reach it (see keymaps.lua),
-- deletes and changes stay inside Neovim
vim.opt.clipboard = ""
