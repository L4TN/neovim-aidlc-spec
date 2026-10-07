local group = vim.api.nvim_create_augroup("AIDLCWorkspace", { clear = true })

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave" }, {
  group = group,
  pattern = "*",
  callback = function()
    if vim.api.nvim_buf_is_valid(0) then
      vim.cmd.checktime()
    end
  end,
  desc = "Reload files changed by external coding agents",
})

require("config.workspaces").setup()
