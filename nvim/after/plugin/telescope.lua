require('telescope').setup {
  defaults = {
    sorting_strategy = "ascending",
    layout_config = { prompt_position = "top" },
  },
  extensions = {
    fzf = {
      fuzzy = true,                    -- false will only do exact matching
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      case_mode = "ignore_case",        -- or "ignore_case" or "respect_case"
                                       -- the default case_mode is "smart_case"
    }
  },
  pickers = {
    find_files = {
      find_command = {'rg', '--files', '--hidden', '--ignore', '-g', '!{node_modules,.git}'},
      hidden = true,
      follow = true,
      no_ignore = true
    }
  }
}
require('telescope').load_extension('fzf')
