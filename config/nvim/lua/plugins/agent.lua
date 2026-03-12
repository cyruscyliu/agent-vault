return {
  {
    "akinsho/toggleterm.nvim",
    opts = function(_, opts)
      local Terminal = require("toggleterm.terminal").Terminal
      local panel_width = math.max(48, math.floor(vim.o.columns * 0.35))
      local panel_height = 14
      local tree_width = 30
      local panels = {}

      local function ensure_server()
        if vim.v.servername ~= nil and vim.v.servername ~= "" then
          return vim.v.servername
        end

        local server = string.format("%s/geek-env-%d.sock", vim.fn.stdpath("run"), vim.fn.getpid())
        pcall(vim.fn.delete, server)
        return vim.fn.serverstart(server)
      end

      local function focus_editor_window()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.api.nvim_win_is_valid(win)
            and not vim.w[win].geek_env_panel_kind
            and vim.bo[buf].filetype ~= "netrw"
          then
            vim.api.nvim_set_current_win(win)
            return true
          end
        end

        vim.cmd("vsplit")
        return true
      end

      local function redirect_normal_buffers()
        local win = vim.api.nvim_get_current_win()
        if not vim.api.nvim_win_is_valid(win) or not vim.w[win].geek_env_panel_kind then
          return
        end

        local buf = vim.api.nvim_win_get_buf(win)
        local kind = vim.w[win].geek_env_panel_kind
        if kind == "tree" and vim.bo[buf].filetype == "netrw" then
          return
        end

        if vim.bo[buf].buftype == "terminal" then
          return
        end

        focus_editor_window()
        vim.api.nvim_set_current_buf(buf)

        local panel = panels[kind]
        if panel and panel.bufnr and vim.api.nvim_buf_is_valid(panel.bufnr) then
          vim.api.nvim_win_set_buf(win, panel.bufnr)
        else
          vim.cmd("bdelete")
        end
      end

      local function protect_tree_window(win, bufnr)
        if not win or not vim.api.nvim_win_is_valid(win) then
          return
        end

        vim.wo[win].winfixbuf = true
        vim.wo[win].winfixwidth = true
        vim.api.nvim_win_set_width(win, tree_width)
        vim.w[win].geek_env_panel_kind = "tree"
        panels.tree = {
          window = win,
          bufnr = bufnr,
        }
      end

      local function protect_terminal_window(term, kind)
        if not term.window or not vim.api.nvim_win_is_valid(term.window) then
          return
        end

        vim.wo[term.window].winfixbuf = true
        vim.w[term.window].geek_env_panel_kind = kind
        if kind == "codex" then
          vim.wo[term.window].winfixwidth = true
          vim.api.nvim_win_set_width(term.window, panel_width)
        else
          vim.wo[term.window].winfixheight = true
          vim.api.nvim_win_set_height(term.window, panel_height)
        end
      end

      local function make_remote_editor()
        local server = ensure_server()
        return string.format("nvim --server %s --remote-tab-wait", vim.fn.shellescape(server))
      end

      local function make_codex_cmd()
        local remote_editor = make_remote_editor()
        return string.format(
          "env EDITOR=%s VISUAL=%s codex",
          vim.fn.shellescape(remote_editor),
          vim.fn.shellescape(remote_editor)
        )
      end

      local function open_tree_panel()
        local editor_win = vim.api.nvim_get_current_win()
        local existing_tree = panels.tree
        if existing_tree
          and existing_tree.window
          and vim.api.nvim_win_is_valid(existing_tree.window)
          and existing_tree.bufnr
          and vim.api.nvim_buf_is_valid(existing_tree.bufnr)
        then
          return
        end

        local before = {}
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          before[win] = true
        end

        vim.cmd("silent keepalt Lexplore")

        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not before[win] then
            protect_tree_window(win, vim.api.nvim_win_get_buf(win))
            break
          end
        end

        if vim.api.nvim_win_is_valid(editor_win) then
          vim.api.nvim_set_current_win(editor_win)
        else
          focus_editor_window()
        end
      end

      local function toggle_panel(term)
        if not term:is_open() then
          focus_editor_window()
        end
        term:toggle()
      end

      local codex = Terminal:new({
        cmd = make_codex_cmd(),
        direction = "vertical",
        size = panel_width,
        hidden = true,
        close_on_exit = false,
        on_open = function(term)
          panels.codex = term
          protect_terminal_window(term, "codex")
        end,
      })

      local shell = Terminal:new({
        cmd = vim.o.shell,
        direction = "horizontal",
        size = panel_height,
        hidden = true,
        close_on_exit = false,
        on_open = function(term)
          panels.shell = term
          protect_terminal_window(term, "shell")
        end,
      })

      vim.api.nvim_create_user_command("CodexToggle", function()
        toggle_panel(codex)
      end, { desc = "Toggle Codex terminal" })

      vim.api.nvim_create_user_command("CodexNew", function()
        focus_editor_window()
        Terminal:new({
          cmd = make_codex_cmd(),
          direction = "vertical",
          size = panel_width,
          close_on_exit = false,
          hidden = true,
          on_open = function(term)
            protect_terminal_window(term, "codex")
          end,
        }):toggle()
      end, { desc = "Open a new Codex terminal" })

      vim.api.nvim_create_user_command("TerminalToggle", function()
        toggle_panel(shell)
      end, { desc = "Toggle shell terminal" })

      vim.api.nvim_create_user_command("TerminalNew", function()
        focus_editor_window()
        Terminal:new({
          cmd = vim.o.shell,
          direction = "horizontal",
          size = panel_height,
          close_on_exit = false,
          hidden = true,
          on_open = function(term)
            protect_terminal_window(term, "shell")
          end,
        }):toggle()
      end, { desc = "Open a new shell terminal" })

      vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
        group = vim.api.nvim_create_augroup("geek_env_protected_panels", { clear = true }),
        callback = redirect_normal_buffers,
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("geek_env_codex", { clear = true }),
        once = true,
        callback = function()
          vim.schedule(function()
            ensure_server()
            local editor_win = vim.api.nvim_get_current_win()
            open_tree_panel()
            if vim.api.nvim_win_is_valid(editor_win) then
              vim.api.nvim_set_current_win(editor_win)
            else
              focus_editor_window()
            end
            codex:open()
            focus_editor_window()
            shell:open()
            if vim.api.nvim_win_is_valid(editor_win) then
              vim.api.nvim_set_current_win(editor_win)
            else
              focus_editor_window()
            end
          end)
        end,
      })

      return opts
    end,
  },
}
