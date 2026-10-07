local M = {}

-- Paths are absolute (via expand) so the workspace grid works no matter
-- which directory Neovim is launched from.
local root = vim.fn.expand("~/source/repos/aidlc-demo")

M.definitions = {
  { name = "Notes", path = root .. "/notes", lazy = false },
  { name = "FrontEnd", path = root .. "/frontend", lazy = false },
  { name = "Backend", path = root .. "/backend", lazy = false },
  { name = "AI Harness", path = root, cmd = "claude", lazy = true },
  { name = "Database", path = root .. "/backend/database", lazy = false },
  { name = "Cache", path = root, cmd = "lazyredis", lazy = true, fullscreen = true },
  { name = "Containers", path = root, cmd = "lazydocker", lazy = true, fullscreen = true },
  { name = "Git", path = root, cmd = "lazygit", lazy = true, fullscreen = true },
  { name = "API", path = root .. "/api", lazy = false },
  {
    name = "Cloud",
    path = root,
    lazy = true,
    env = {
      AWS_PROFILE = "dev",
      AZURE_CONFIG_DIR = vim.fn.expand("~/.azure-dev"),
    },
  },
  { name = "Logs", path = root, lazy = true },
}

local initializing = false
local initialized = false
local warned_missing = false

local function get_tab_var(tab, key, fallback)
  local ok, value = pcall(vim.api.nvim_tabpage_get_var, tab, key)
  if ok then
    return value
  end
  return fallback
end

local function set_tab_var(tab, key, value)
  pcall(vim.api.nvim_tabpage_set_var, tab, key, value)
end

local function tab_cwd(tab)
  local number = vim.api.nvim_tabpage_get_number(tab)
  return vim.fn.getcwd(-1, number)
end

local function is_absolute(path)
  return path:match("^[/\\\\]") ~= nil or path:match("^%a:[/\\\\]") ~= nil
end

local function expand_path(path, base)
  path = vim.fn.expand(path)
  if not is_absolute(path) then
    path = vim.fs.joinpath(base or tab_cwd(vim.api.nvim_get_current_tabpage()), path)
  end
  return vim.fs.normalize(path)
end

local function definition_for_tab(tab)
  local name = get_tab_var(tab, "workspace_name", nil)
  for _, definition in ipairs(M.definitions) do
    if definition.name == name then
      return definition
    end
  end
  return {
    name = name or "Project",
    path = get_tab_var(tab, "workspace_path", tab_cwd(tab)),
    cmd = get_tab_var(tab, "workspace_cmd", nil),
    env = get_tab_var(tab, "workspace_env", {}),
    lazy = get_tab_var(tab, "workspace_lazy", false),
    fullscreen = get_tab_var(tab, "workspace_fullscreen", false),
  }
end

function M.cwd(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  return tab_cwd(tab)
end

function M.env_for(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local definition = definition_for_tab(tab)
  local env = {}
  for key, value in pairs(definition.env or {}) do
    env[key] = tostring(value)
  end
  local tab_env = get_tab_var(tab, "workspace_env", {})
  if type(tab_env) == "table" then
    for key, value in pairs(tab_env) do
      env[key] = tostring(value)
    end
  end
  return env
end

local function set_workspace(tab, definition, path, env)
  set_tab_var(tab, "tab_name", definition.name)
  set_tab_var(tab, "workspace_name", definition.name)
  set_tab_var(tab, "workspace_path", path)
  set_tab_var(tab, "workspace_env", env or definition.env or {})
  set_tab_var(tab, "workspace_cmd", definition.cmd)
  set_tab_var(tab, "workspace_lazy", definition.lazy == true)
  set_tab_var(tab, "workspace_fullscreen", definition.fullscreen == true)
  set_tab_var(tab, "workspace_started", false)
  local current = vim.api.nvim_get_current_tabpage()
  if current ~= tab then
    vim.api.nvim_set_current_tabpage(tab)
  end
  vim.api.nvim_cmd({ cmd = "tcd", args = { path } }, {})
  if current ~= tab and vim.api.nvim_tabpage_is_valid(current) then
    vim.api.nvim_set_current_tabpage(current)
  end
end

local function parse_args(line)
  local args, current, quote = {}, {}, nil
  for i = 1, #line do
    local char = line:sub(i, i)
    if quote then
      if char == quote then
        quote = nil
      else
        current[#current + 1] = char
      end
    elseif char == "'" or char == '"' then
      quote = char
    elseif char:match("%s") then
      if #current > 0 then
        args[#args + 1] = table.concat(current)
        current = {}
      end
    else
      current[#current + 1] = char
    end
  end
  if #current > 0 then
    args[#args + 1] = table.concat(current)
  end
  return args
end

local function parse_env(value)
  local env = {}
  for item in (value or ""):gmatch("[^;]+") do
    local key, entry = item:match("^%s*([%a_][%w_]*)%s*=(.*)%s*$")
    if key then
      env[key] = entry
    elseif item:match("%S") then
      vim.notify("Ignoring invalid environment entry: " .. item, vim.log.levels.WARN)
    end
  end
  return env
end

local function create_project_tab(path, name, env_string)
  local absolute = expand_path(path)
  if vim.fn.isdirectory(absolute) ~= 1 then
    vim.notify("Project directory does not exist: " .. absolute, vim.log.levels.ERROR)
    return
  end
  name = vim.trim(name or "")
  if name == "" then
    name = vim.fn.fnamemodify(absolute, ":t")
  end

  vim.cmd.tabnew()
  local tab = vim.api.nvim_get_current_tabpage()
  set_workspace(tab, { name = name, lazy = false }, absolute, parse_env(env_string))
  pcall(vim.cmd, "Neotree filesystem reveal")
  vim.cmd("redrawtabline")
end

function M.new_project(args)
  local parsed = parse_args(args or "")
  local path = parsed[1] or vim.fn.input("Project path: ", M.cwd())
  if path == "" then
    return
  end
  local name = parsed[2] or vim.fn.input("Tab name: ", vim.fn.fnamemodify(path, ":t"))
  if name == "" then
    name = vim.fn.fnamemodify(path, ":t")
  end
  local env_string = parsed[3] or vim.fn.input("Tab environment (KEY=VALUE;KEY=VALUE, optional): ")
  create_project_tab(path, name, env_string)
end

local function metadata_file()
  local root = vim.fs.normalize(vim.fn.getcwd())
  local directory = vim.fs.joinpath(vim.fn.stdpath("state"), "aidlc-workspaces")
  vim.fn.mkdir(directory, "p")
  return vim.fs.joinpath(directory, vim.fn.sha256(root) .. ".json")
end

function M.save_metadata()
  local saved = {}
  for index, info in ipairs(vim.fn.gettabinfo()) do
    local tab = vim.api.nvim_list_tabpages()[index]
    saved[index] = {
      name = get_tab_var(tab, "tab_name", ""),
      path = tab_cwd(tab),
      cmd = get_tab_var(tab, "workspace_cmd", nil),
      lazy = get_tab_var(tab, "workspace_lazy", false),
      fullscreen = get_tab_var(tab, "workspace_fullscreen", false),
    }
  end
  local ok, encoded = pcall(vim.json.encode, saved)
  if ok then
    vim.fn.writefile({ encoded }, metadata_file())
  end
end

function M.restore_metadata()
  local file = metadata_file()
  if vim.fn.filereadable(file) ~= 1 then
    return
  end
  local ok, saved = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
  if not ok or type(saved) ~= "table" then
    return
  end
  local tabs = vim.api.nvim_list_tabpages()
  for index, state in ipairs(saved) do
    local tab = tabs[index]
    if tab and type(state) == "table" then
      local path = state.path or vim.fn.getcwd()
      if vim.fn.isdirectory(path) ~= 1 then
        path = vim.fn.getcwd()
      end
      local definition
      for _, candidate in ipairs(M.definitions) do
        if candidate.name == state.name then
          definition = candidate
          break
        end
      end
      definition = definition or {
        name = state.name or "Project",
        cmd = state.cmd,
        lazy = state.lazy,
        fullscreen = state.fullscreen,
      }
      -- Environment values from dynamically-created tabs are deliberately not serialized.
      set_workspace(tab, definition, path, definition.env or {})
    end
  end
  vim.cmd("redrawtabline")
end

local function refresh_cloud_status(tab)
  local definition = definition_for_tab(tab)
  if definition.name ~= "Cloud" then
    return
  end
  local env = M.env_for(tab)
  local profile = env.AWS_PROFILE or "default"
  set_tab_var(tab, "cloud_status", profile .. " | Azure: checking")
  vim.cmd("redrawtabline")
  if vim.fn.executable("az") ~= 1 then
    set_tab_var(tab, "cloud_status", profile .. " | Azure: CLI missing")
    vim.cmd("redrawtabline")
    return
  end
  local command = { "az", "account", "show", "--query", "name", "-o", "tsv" }
  if vim.fn.has("win32") == 1 then
    -- Azure CLI is installed as az.cmd on Windows; libuv needs cmd.exe for .cmd files.
    command = { "cmd.exe", "/d", "/s", "/c", "az account show --query name -o tsv" }
  end
  vim.system(command, {
    text = true,
    env = env,
  }, function(result)
    vim.schedule(function()
      if not vim.api.nvim_tabpage_is_valid(tab) then
        return
      end
      local subscription = result.code == 0 and vim.trim(result.stdout or "") or "not logged in"
      set_tab_var(tab, "cloud_status", profile .. " | Azure: " .. (subscription ~= "" and subscription or "not logged in"))
      vim.cmd("redrawtabline")
    end)
  end)
end

local function launch_lazy_command(tab)
  local definition = definition_for_tab(tab)
  if not definition.lazy or not definition.cmd or get_tab_var(tab, "workspace_started", false) then
    return
  end
  set_tab_var(tab, "workspace_started", true)
  vim.schedule(function()
    if not vim.api.nvim_tabpage_is_valid(tab) then
      return
    end
    local ok, terminals = pcall(require, "config.terminals")
    if ok then
      terminals.run_command(tab, definition.cmd, definition.fullscreen)
    else
      vim.notify("ToggleTerm is not available: " .. tostring(terminals), vim.log.levels.ERROR)
    end
  end)
end

function M.initialize()
  if initialized then
    return
  end
  initialized = true
  if vim.fn.argc() > 0 then
    return
  end

  initializing = true
  local root = vim.fn.getcwd()
  local tabs = {}
  local missing = {}
  for index, definition in ipairs(M.definitions) do
    if index > 1 then
      vim.cmd.tabnew()
    end
    local tab = vim.api.nvim_get_current_tabpage()
    tabs[#tabs + 1] = tab
    local path = expand_path(definition.path, root)
    if vim.fn.isdirectory(path) ~= 1 then
      missing[#missing + 1] = vim.fn.fnamemodify(path, ":.")
      path = root
    end
    set_workspace(tab, definition, path, definition.env)
  end
  vim.cmd("tabnext 1")
  initializing = false
  if #missing > 0 and not warned_missing then
    warned_missing = true
    vim.notify(
      "Some workspace folders are missing and currently point to the project root: " .. table.concat(missing, ", "),
      vim.log.levels.WARN
    )
  end
  vim.cmd("redrawtabline")
end

function M.tabline()
  local output = {}
  local current = vim.api.nvim_get_current_tabpage()
  for index, info in ipairs(vim.fn.gettabinfo()) do
    local tab = info.tabnr
    local name = vim.fn.gettabvar(tab, "tab_name", "")
    if name == "" then
      name = vim.fn.fnamemodify(vim.fn.getcwd(-1, tab), ":t")
    end
    local cloud = vim.fn.gettabvar(tab, "cloud_status", "")
    if cloud ~= "" then
      name = name .. " [" .. cloud .. "]"
    end
    name = tostring(name):gsub("%%", "%%%%")
    local handle = vim.api.nvim_list_tabpages()[index]
    local highlight = handle == current and "%#TabLineSel#" or "%#TabLine#"
    output[#output + 1] = highlight .. string.format("%%%dT%d:%s%%T", index, index, name)
  end
  output[#output + 1] = "%#TabLineFill#%T"
  return table.concat(output)
end

function M.setup()
  vim.api.nvim_create_user_command("NewTabProject", function(command)
    M.new_project(command.args)
  end, { nargs = "*", desc = "Open an isolated project in a new tab" })

  local group = vim.api.nvim_create_augroup("AIDLCWorkspaces", { clear = true })
  -- This module is loaded on VeryLazy when Neovim starts without file arguments,
  -- so VimEnter may already have happened. Scheduling works in both load orders.
  vim.schedule(M.initialize)
  vim.api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = function()
      if initializing then
        return
      end
      local tab = vim.api.nvim_get_current_tabpage()
      launch_lazy_command(tab)
      refresh_cloud_status(tab)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.save_metadata,
    desc = "Save workspace names and tab-local directories",
  })
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      M.restore_metadata()
      local tab = vim.api.nvim_get_current_tabpage()
      launch_lazy_command(tab)
    end,
    desc = "Restore AIDLC tab names after a session restore",
  })
end

return M
