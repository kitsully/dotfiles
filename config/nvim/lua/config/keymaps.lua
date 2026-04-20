-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Use jk to escape terminal and jump back to previous window
-- (Esc is intercepted by Claude Code's vim mode)
vim.keymap.set("t", "jk", "<C-\\><C-n><C-w>p", { desc = "Escape terminal and return to previous window" })
vim.keymap.set("n", ";", ":", { desc = "Command mode" })
