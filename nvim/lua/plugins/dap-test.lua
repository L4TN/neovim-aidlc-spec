return {
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "netcoredbg", "js-debug-adapter" })
    end,
  },
  {
    "nvim-neotest/neotest",
    cmd = "Neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "Issafalcon/neotest-dotnet",
      "nvim-neotest/neotest-jest",
      "marilari88/neotest-vitest",
    },
    config = function()
      local adapters = { require("neotest-dotnet") }
      local package_file = vim.fs.joinpath(vim.fn.getcwd(), "package.json")
      if vim.fn.filereadable(package_file) == 1 then
        local ok, package = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_file), "\n"))
        if ok and type(package) == "table" then
          local deps = vim.tbl_extend("force", package.dependencies or {}, package.devDependencies or {})
          if deps.vitest then
            table.insert(adapters, require("neotest-vitest"))
          elseif deps.jest then
            table.insert(adapters, require("neotest-jest")({ jestCommand = "npm test --" }))
          end
          -- Karma has no Neotest adapter; run it from the API/FrontEnd terminal.
        end
      end
      require("neotest").setup({ adapters = adapters })
    end,
  },
}
