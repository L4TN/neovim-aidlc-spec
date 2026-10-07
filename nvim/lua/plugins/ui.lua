return {
  -- 2026-10-07: Windows Smart App Control was disabled on this PC, which
  -- unblocked Mason's tree-sitter.exe (verified: tree-sitter 0.27.0 runs).
  -- nvim-treesitter, textobjects and render-markdown.nvim use LazyVim defaults.
  {
    "folke/snacks.nvim",
    opts = { explorer = { enabled = false } },
    keys = {
      { "<leader>e", false },
      { "<C-/>", false },
    },
  },
  { "akinsho/bufferline.nvim", enabled = false },
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = "Neotree",
    opts = {
      filesystem = {
        bind_to_cwd = true,
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
      },
    },
  },
  {
    "tiagovla/scope.nvim",
    event = "VeryLazy",
    config = function()
      require("scope").setup({})
    end,
  },
}
