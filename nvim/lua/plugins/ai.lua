return {
  {
    "coder/claudecode.nvim",
    cmd = {
      "ClaudeCode",
      "ClaudeCodeFocus",
      "ClaudeCodeSelectModel",
      "ClaudeCodeAdd",
      "ClaudeCodeSend",
      "ClaudeCodeTreeAdd",
      "ClaudeCodeStatus",
    },
    dependencies = { "folke/snacks.nvim" },
    opts = {},
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Claude Code" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude Code" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = { "n", "v" }, desc = "Send to Claude Code" },
    },
  },
}
