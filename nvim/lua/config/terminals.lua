local M = { shells = {}, commands = {}, next_id = 8000 }

local function next_id()
  M.next_id = M.next_id + 1
  return M.next_id
end

local function terminal_module()
  return require("toggleterm.terminal").Terminal
end

local function terminal_options(tab, command, fullscreen, display_name)
  local workspaces = require("config.workspaces")
  local opts = {
    id = next_id(),
    cmd = command,
    dir = workspaces.cwd(tab),
    direction = "horizontal",
    size = fullscreen and math.max(12, vim.o.lines - 4) or 14,
    hidden = true,
    close_on_exit = false,
    display_name = display_name,
  }
  -- Neovim 0.12 termopen rejects an empty env table with E475 "Invalid
  -- argument: env", so only pass env when the tab defines one.
  local env = workspaces.env_for(tab)
  if next(env) ~= nil then
    opts.env = env
  end
  return opts
end

local function with_tab(tab, callback)
  if not vim.api.nvim_tabpage_is_valid(tab) then
    return
  end
  local current = vim.api.nvim_get_current_tabpage()
  if current ~= tab then
    vim.api.nvim_set_current_tabpage(tab)
  end
  callback()
  if current ~= tab and vim.api.nvim_tabpage_is_valid(current) then
    vim.api.nvim_set_current_tabpage(current)
  end
end

function M.toggle_shell()
  local tab = vim.api.nvim_get_current_tabpage()
  if not M.shells[tab] then
    M.shells[tab] = terminal_module():new(terminal_options(tab, nil, false, "Workspace shell"))
  end
  M.shells[tab]:toggle()
end

function M.run_command(tab, command, fullscreen)
  if not command or command == "" then
    return
  end
  local actual = command
  if actual == "lazyredis" and vim.fn.executable(actual) ~= 1 then
    actual = vim.fn.executable("redis-cli") == 1 and "redis-cli" or actual
  end
  if vim.fn.executable(actual) ~= 1 then
    vim.notify(
      "Command '" .. actual .. "' is not installed. Install it or run it from this tab's terminal.",
      vim.log.levels.WARN
    )
    return
  end

  local existing = M.commands[tab]
  if existing and existing.command == actual then
    with_tab(tab, function()
      existing.terminal:toggle()
    end)
    return
  end

  local terminal = terminal_module():new(terminal_options(tab, actual, fullscreen, actual))
  M.commands[tab] = { command = actual, terminal = terminal }
  with_tab(tab, function()
    terminal:toggle()
  end)
end

function M.run_current_workspace()
  local tab = vim.api.nvim_get_current_tabpage()
  local definition = require("config.workspaces").definitions
  local name = vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(tab), "workspace_name", "")
  for _, workspace in ipairs(definition) do
    if workspace.name == name and workspace.cmd then
      M.run_command(tab, workspace.cmd, workspace.fullscreen)
      return
    end
  end
  local custom_command = vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(tab), "workspace_cmd", nil)
  if custom_command then
    M.run_command(tab, custom_command, vim.fn.gettabvar(vim.api.nvim_tabpage_get_number(tab), "workspace_fullscreen", false))
  else
    vim.notify("This workspace has no startup command", vim.log.levels.INFO)
  end
end

return M
