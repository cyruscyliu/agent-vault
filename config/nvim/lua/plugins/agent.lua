return {
  {
    "akinsho/toggleterm.nvim",
    opts = function(_, opts)
      local Terminal = require("toggleterm.terminal").Terminal
      local codex = Terminal:new({
        cmd = "codex",
        direction = "vertical",
        size = math.floor(vim.o.columns * 0.35),
        hidden = true,
        close_on_exit = false,
      })

      vim.api.nvim_create_user_command("CodexToggle", function()
        codex:toggle()
      end, { desc = "Toggle Codex terminal" })

      vim.api.nvim_create_user_command("CodexNew", function()
        Terminal:new({
          cmd = "codex",
          direction = "vertical",
          size = math.floor(vim.o.columns * 0.35),
          close_on_exit = false,
          hidden = true,
        }):toggle()
      end, { desc = "Open a new Codex terminal" })

      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("geek_env_codex", { clear = true }),
        once = true,
        callback = function()
          vim.schedule(function()
            codex:open()
            vim.cmd("wincmd p")
          end)
        end,
      })

      return opts
    end,
  },
}
