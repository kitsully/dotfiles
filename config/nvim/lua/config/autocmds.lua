-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "*.docx",
  callback = function()
    local file = vim.fn.shellescape(vim.api.nvim_buf_get_name(0))
    local content = vim.fn.systemlist("docx2txt.pl " .. file .. " -")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
    vim.bo.filetype = "text"
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end,
})
