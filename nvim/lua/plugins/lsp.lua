return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      }
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "roslyn", "hadolint", "actionlint" })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      -- The current LazyVim .NET extra supplies OmniSharp as a fallback.
      -- Prefer roslyn.nvim on Neovim 0.12+, leaving OmniSharp disabled by default.
      opts.servers.omnisharp = { enabled = false }
      opts.servers.yamlls = opts.servers.yamlls or {}
      opts.servers.dockerls = opts.servers.dockerls or {}
      opts.servers.docker_compose_language_service = opts.servers.docker_compose_language_service or {}
    end,
  },
  {
    "seblyng/roslyn.nvim",
    ft = { "cs" },
    opts = {},
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      local function add_formatter(ft, formatter)
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        if not vim.tbl_contains(opts.formatters_by_ft[ft], formatter) then
          table.insert(opts.formatters_by_ft[ft], 1, formatter)
        end
      end
      add_formatter("cs", "csharpier")
      for _, ft in ipairs({ "typescript", "typescriptreact", "javascript", "javascriptreact", "html", "css", "scss", "json", "jsonc", "markdown", "yaml", "angular" }) do
        add_formatter(ft, "prettier")
      end
    end,
  },
}
