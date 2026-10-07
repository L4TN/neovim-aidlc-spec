vim.opt.autoread = true
vim.opt.hidden = true
vim.opt.showtabline = 2
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 500
vim.opt.confirm = true
vim.opt.tabline = "%!v:lua.require'config.workspaces'.tabline()"

-- LazyVim's TypeScript extra defaults to vtsls; keep Angular and TS on one server.
vim.g.lazyvim_ts_lsp = "vtsls"

-- 2026-10-07: Smart App Control was disabled on this PC, unblocking Mason's
-- tree-sitter.exe. The previous graceful fallback for "Parser could not be
-- created" was removed; parsers are installed by nvim-treesitter.

-- Bruno collections are plain-text files; no dedicated parser is required.
vim.filetype.add({ extension = { bru = "bru" } })
