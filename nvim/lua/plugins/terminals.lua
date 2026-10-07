return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    lazy = false,
    opts = {
      direction = "horizontal",
      size = 14,
      autochdir = false,
      start_in_insert = true,
      insert_mappings = false,
      terminal_mappings = false,
      persist_size = true,
      close_on_exit = false,
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)
      vim.api.nvim_create_user_command("WorkspaceCommand", function()
        require("config.terminals").run_current_workspace()
      end, { desc = "Run this tab's workspace command" })
    end,
  },
}
