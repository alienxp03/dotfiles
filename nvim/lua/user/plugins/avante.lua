return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  build = "make BUILD_FROM_SOURCE=true",
  opts = {
    provider = "gemini",
    gemini = {
      endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
      -- model = "gemini-1.5-flash-latest",
      model = "gemini-2.0-flash-exp",
      timeout = 30000, -- Timeout in milliseconds
      temperature = 0,
      max_tokens = 4096,
    },
  },
}
