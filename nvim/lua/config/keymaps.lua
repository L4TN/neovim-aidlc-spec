local map = vim.keymap.set

-- LazyVim's Snacks terminal is intentionally replaced by one ToggleTerm per tab.
local function disable_snacks_terminal_maps()
  for _, key in ipairs({ "<C-/>", "<C-_>", "<leader>fT", "<leader>ft" }) do
    pcall(vim.keymap.del, "n", key)
    pcall(vim.keymap.del, "t", key)
  end
end
disable_snacks_terminal_maps()
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyVimKeymaps",
  once = true,
  callback = disable_snacks_terminal_maps,
})
map("n", "<C-\\>", function()
  require("config.terminals").toggle_shell()
end, { desc = "Toggle this tab's terminal" })

map("t", "<Esc><Esc>", [[<C-\\><C-n>]], { desc = "Terminal: return to normal mode" })
for key, direction in pairs({ h = "h", j = "j", k = "k", l = "l" }) do
  map("t", "<C-" .. key .. ">", [[<C-\\><C-n><Cmd>wincmd ]] .. direction .. [[<CR>]], {
    desc = "Terminal: move to " .. direction,
  })
end

map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Explorer (Neo-tree)" })
map("n", "<leader>D", "<cmd>DBUIToggle<cr>", { desc = "Database UI" })
map("n", "<leader><tab>n", "<cmd>NewTabProject<cr>", { desc = "New project tab" })
map("n", "<leader><tab>0", "<cmd>tabmove 0<cr>", { desc = "Move tab to start" })
map("n", "<leader><tab>$", "<cmd>tabmove $<cr>", { desc = "Move tab to end" })
map("n", "<A-Right>", "<cmd>tabmove +1<cr>", { desc = "Move tab right" })
map("n", "<A-Left>", "<cmd>tabmove -1<cr>", { desc = "Move tab left" })
map("n", "<leader>od", function()
  vim.ui.open("https://app.datadoghq.com/logs")
end, { desc = "Open Datadog logs" })

local function copy(value)
  if not value or value == "" then
    vim.notify("There is no file path to copy", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", value)
  vim.notify("Copied: " .. value)
end

local function current_path()
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
end

local function relative_path()
  local path = current_path()
  if path == "" then
    return ""
  end
  local root = vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(0))
  return vim.fs.relpath(root, path) or path
end

map("n", "<leader>yp", function()
  copy(current_path())
end, { desc = "Copy absolute file path" })
map("n", "<leader>yr", function()
  copy(relative_path())
end, { desc = "Copy path relative to this tab" })
map("n", "<leader>yl", function()
  local path = relative_path()
  if path ~= "" then
    copy(path .. ":" .. vim.api.nvim_win_get_cursor(0)[1])
  end
end, { desc = "Copy path and current line" })
map("x", "<leader>yl", function()
  local path = relative_path()
  local first = vim.fn.line("'<")
  local last = vim.fn.line("'>")
  if path ~= "" then
    copy(path .. ":" .. first .. (first == last and "" or "-" .. last))
  end
end, { desc = "Copy path and selected lines" })
map("n", "<leader>ya", function()
  local path = relative_path()
  if path ~= "" then
    copy("@" .. path)
  end
end, { desc = "Copy Claude @-reference" })
