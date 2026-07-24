local function format_file_columns(item, picker)
  local path = Snacks.picker.util.path(item) or item.file
  local filename = vim.fn.fnamemodify(path, ":t")
  local directory = vim.fn.fnamemodify(path, ":h")
  local filename_width = 32
  local padding = math.max(2, filename_width - vim.fn.strdisplaywidth(filename))

  if directory == "." then
    directory = ""
  end

  if vim.fn.strdisplaywidth(directory) > 60 then
    directory = Snacks.picker.util.truncpath(directory, 60, {
      cwd = picker:cwd(),
      kind = "left",
    })
  end

  local base_hl = item.dir and "SnacksPickerDirectory" or "SnacksPickerFile"
  local category = item.dir and "directory" or "file"
  local icon, icon_hl = Snacks.util.icon(path, category, {
    fallback = picker.opts.icons.files,
  })
  icon = Snacks.picker.util.align(icon, picker.opts.formatters.file.icon_width or 2)

  return {
    { icon, icon_hl, virtual = true },
    { filename, icon_hl or base_hl, field = "file" },
    { string.rep(" ", padding) },
    { directory, "SnacksPickerDir", field = "file" },
  }
end

return {
  "folke/snacks.nvim",
  lazy = false,
  opts = {
    scope = {
      treesitter = {
        injections = false,
      },
    },
    picker = {
      hidden = true,
      ignored = true,
      enabled = true,
      formatters = {
        file = {
          filename_first = true,
          truncate = 100,
        },
      },
      layout = {
        cycle = false,
        preset = "ivy",
        layout = {
          backdrop = false,
          width = 0.8,
          min_width = 80,
          height = 0.9,
          min_height = 30,
          box = "vertical",
          border = "rounded",
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
          { win = "preview", title = "{preview}", height = 0.7, border = "top" },
        },
      },
      win = {
        input = {
          keys = {
            ["<C-h>"] = { "toggle_ignored", mode = { "i", "n" } },
          },
        },
      },
      matcher = {
        frecency = true,
      },
      sources = {
        files = {
          ignored = true,
          hidden = true,
          exclude = { "**/.DS_Store", "**/node_modules/**" },
        },
        explorer = {
          layout = { preview = true },
          ignored = true,
          hidden = true,
          exclude = { "**/.DS_Store" },
          auto_close = true,
          jump = { close = true },
        },
        grep = { ignored = false, hidden = true, regex = false },
        grep_word = { ignored = false, hidden = true },
        grep_buffers = { ignored = false, hidden = true },
      },
    },
    animate = {
      enabled = true,
      duration = 30,
      easing = "linear",
      fps = 60,
    },
    bigfile = {
      enabled = true,
      notify = true,
    },
    indent = { enabled = true },
    input = { enabled = true },
    lazygit = { configure = true },
    bufdelete = { configure = true },
    win = {
      width = 0.95,
      height = 0.95,
    },
    image = { enabled = true },
    notifier = { enabled = false },
    -- ascii pokemon
    dashboard = {
      enabled = true,
      preset = {
        header = [[
⡐⢂⠲⡐⢢⢀⠂⡔⠠⠒⡄⢃⡒⠔⡂⠖⡐⢆⠒⡔⢂⠲⡐⢂⠖⡐⢢⠒⡰⢂⡈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⠰⡉⢆⢡⠃⣄⠣⢀⠣⠄⢘⡡⠘⡄⢣⢘⠰⣈⠒⡌⡘⠤⡑⢊⠔⡉⢆⠱⢠⠃⡄⣹⣿⣿⣿⣿⣿⣿⣿⣿⣿⢿⣻⡽⣯⠟
⢂⠱⡈⠆⣸⢆⠡⢂⠒⣈⠐⡄⢋⠔⡡⢊⠔⢢⠑⡄⢃⡒⢡⠊⡔⢡⠊⡔⢡⠊⡔⢙⣿⣿⣿⣿⣿⣿⣿⣿⣟⣯⢿⡽⢧⢋
⡈⢆⡑⢲⢻⣌⡳⣌⢶⣠⢃⠘⠤⢊⠔⡡⢊⠤⢃⠜⡰⢈⠆⡱⢈⠆⡱⢈⠆⡱⢈⠜⣿⣿⣿⣿⣿⣿⣿⣿⢯⣟⣯⣟⡯⢆
⡐⢂⠀⡀⠁⢚⠿⣽⣻⢾⣭⠎⡐⢣⠘⡄⢣⠘⡄⢎⠰⡁⢎⠰⡁⢎⠰⡁⢎⠰⡁⠆⢿⡿⣿⣿⣿⣿⡿⣯⣿⣻⢾⣽⣛⡆
⡘⢄⣀⠀⠸⣿⣿⣶⣭⡛⢾⣓⠈⢆⠱⡈⢆⠱⡈⢆⠱⡈⢆⠱⡈⢆⠱⡈⢆⠱⣈⠱⡘⠿⡽⢻⡞⣷⢻⢯⠷⣟⠿⠾⠝⠂
⠌⣸⣿⢿⡄⢻⣿⣿⣿⣿⣷⣦⣉⠢⡑⢌⠢⡑⢌⠢⡑⢌⠢⡑⢌⠢⡑⢌⠢⡑⠤⢃⠄⠰⢀⠃⡐⠠⠂⣀⣢⣴⣶⣿⡇⠀
⢲⣿⢯⣟⣷⡘⣿⣿⣿⣿⣿⣿⣿⣷⣮⡀⢇⡘⢄⠣⡘⢄⠣⡘⢄⠣⡘⢢⢑⡘⡰⢉⠜⠀⡌⣤⣴⣶⣿⣿⣿⣿⣿⣿⠇⠀
⣿⢯⣟⡿⣞⠳⡘⢿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡘⠄⢣⣜⣀⣃⣘⣂⣡⣑⣂⣈⢐⣁⣎⣶⣷⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⡐
⣿⢯⡿⣽⢏⢣⠐⡈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⣀⠔⡠
⠌⢋⡙⠤⠋⢄⠃⠤⠁⠙⢿⣿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⣡⣾⢯⣟⡔
⠀⠂⠀⠄⢁⠂⠌⠤⢁⠂⠀⢡⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⡻⢋⣥⣾⡿⣯⣟⡾⡐
⠀⠀⠀⠀⠀⡈⠰⢈⠆⡘⢠⣿⣿⣿⣿⡿⠛⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⢿⣿⣿⣿⣿⣿⣷⡜⢯⣷⣻⢷⡻⣜⠡
⠀⠀⠀⠀⠀⢀⠡⢊⠔⣉⣾⣿⣿⣿⣿⠘⠛⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠘⠟⠀⣿⣿⣿⣿⣿⣿⣿⡨⢓⡹⢎⡱⢌⠡
⠀⠀⠀⠀⠀⠀⠂⠥⡚⣼⣿⣿⣿⣿⣿⣶⣤⣾⣿⣿⣿⡿⠿⣿⣿⣿⣿⣿⣿⣷⣤⣶⣿⣿⣿⣿⣿⣿⣿⣇⠡⠒⢄⠒⡨⠐
⠀⠀⠀⠀⠀⠠⡉⢦⢡⡿⢟⡻⠟⠿⣿⣿⣿⣿⣿⣿⣿⣷⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⡿⢟⢻⡛⢻⣿⣿⣿⡄⢡⠊⠤⡑⠌
⢀⡄⣄⢢⣌⡵⣜⣮⢹⣡⠚⣔⢋⢎⣹⣿⣿⣿⣿⣿⣿⡿⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⠔⣊⠦⣍⢣⢾⣿⣿⡧⢮⣝⣲⢡⢊
⣾⣼⣞⡷⣾⣽⣻⢾⣸⣷⣼⣬⣷⣴⣿⣿⣿⣿⣿⣿⡏⣾⣿⣿⣿⣷⢹⣿⣿⣿⣿⣿⣲⣩⣶⣬⣶⣾⣿⣿⣿⠾⣽⣳⣏⠆
⣿⢾⣽⣻⢷⣯⣟⣯⣧⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣙⣿⠿⡿⣏⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣿⣳⢿⡌
⣿⢯⣷⢿⣻⡾⣽⣳⣯⢧⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⣾⣽⡻⡔
⣟⡿⣞⣯⢷⣻⣽⣳⢯⡟⣇⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠓⣯⠳⠌
⠸⢹⠙⡎⢏⠳⢍⠫⡙⡜⢄⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠣⡙⡐
      ]],
      },
      sections = {
        { section = "header" },
      },
    },
  },
  keys = {
    {
      "<C-q>",
      function()
        Snacks.bufdelete({ wipe = true })
      end,
      desc = "Delete buffer",
    },
    {
      "<leader>ff",
      function()
        Snacks.picker.files({ format = format_file_columns })
      end,
      desc = "Search files",
    },
    {
      "<C-p>",
      function()
        Snacks.picker.files({ format = format_file_columns })
      end,
      desc = "Search files",
    },
    {
      "<leader>fg",
      function()
        Snacks.picker.grep()
      end,
      desc = "Live grep",
    },
    {
      "<C-f>",
      function()
        Snacks.picker.grep()
      end,
      desc = "Grep",
    },
    {
      "<leader>ft",
      function()
        Snacks.picker.lines({
          layout = { preview = true },
          on_close = function(item)
            local pattern = item.input.filter.pattern
            vim.fn.setreg("/", pattern)
          end,
          matcher = {
            fuzzy = false,
            smartcase = true,
            ignorecase = true,
            sort_empty = false,
          },
          sort = {
            fields = {
              "lnum",
            },
          },
        })
      end,
      desc = "Grep current buffer",
    },
    {
      "<C-t>",
      function()
        Snacks.picker.lines({
          layout = { preview = true },
          on_close = function(item)
            local pattern = item.input.filter.pattern
            vim.fn.setreg("/", pattern)
          end,
          matcher = {
            fuzzy = false,
            smartcase = true,
            ignorecase = true,
            sort_empty = false,
          },
          sort = {
            fields = {
              "lnum",
            },
          },
        })
      end,
      desc = "Grep current buffer",
    },
    {
      "<C-b>",
      function()
        Snacks.picker.buffers({
          on_show = function()
            -- Always start in normal mode
            vim.cmd.stopinsert()
          end,
          finder = "buffers",
          format = "buffer",
          hidden = false,
          unloaded = true,
          current = true,
          sort_lastused = true,
          win = {
            input = {
              keys = {
                ["d"] = "bufdelete",
              },
            },
            list = { keys = { ["d"] = "bufdelete" } },
          },
        })
      end,
      desc = "Buffers",
    },
    {
      "<leader>sr",
      function()
        Snacks.picker.resume()
      end,
      desc = "Resume",
    },
    {
      "<leader>gg",
      function()
        Snacks.lazygit()
      end,
      desc = "Toggle Lazygit",
    },
    {
      "<leader>gl",
      function()
        Snacks.lazygit.log()
      end,
      desc = "Git Log",
    },
    {
      "<leader>gf",
      function()
        Snacks.lazygit.log_file()
      end,
      desc = "Current File Git History",
    },
    {
      "<leader>gs",
      function()
        Snacks.picker.git_status()
      end,
      desc = "Git status",
    },
    {
      "<leader>gb",
      function()
        Snacks.picker.git_branches({})
      end,
      desc = "Branches",
    },
    {
      "<leader>go",
      function()
        Snacks.gitbrowse()
      end,
      desc = "Git browse",
    },
    {
      "<leader>ld",
      function()
        Snacks.picker.lsp_definitions({ auto_confirm = false })
      end,
      desc = "LSP definitions",
    },
    {
      "<leader>lf",
      function()
        Snacks.picker.lsp_references({ auto_confirm = false })
      end,
      desc = "LSP references",
    },
    {
      "<leader>lm",
      function()
        Snacks.picker.lsp_implementations({ auto_confirm = false })
      end,
      desc = "LSP implementations",
    },
    {
      "<leader>ls",
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = "LSP symbols",
    },
    {
      "<leader>sk",
      function()
        Snacks.picker.keymaps()
      end,
      desc = "Keymaps",
    },
    {
      "<leader>sv",
      function()
        Snacks.picker.files({ cwd = vim.fn.getcwd() .. "/vendor" })
      end,
      desc = "Search in vendor",
    },
    {
      "<leader>sm",
      function()
        Snacks.picker.marks()
      end,
      desc = "Marks",
    },
    {
      "<leader>su",
      function()
        Snacks.picker.undo()
      end,
      desc = "Undo history",
    },
    {
      "<leader>sn",
      function()
        Snacks.picker.notifications()
      end,
      desc = "Notifications",
    },
    {
      "<leader>st",
      function()
        Snacks.picker.colorschemes()
      end,
      desc = "Colorschemes",
    },
    {
      "<leader>sg",
      function()
        require("user.util.pick_directory")("grep")
      end,
      desc = "Grep (pick folder first)",
    },
  },
}
