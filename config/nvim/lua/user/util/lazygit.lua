local M = {}
local opening = false

function M.open()
  local session, block = vim.env.REX_SESSION, vim.env.REX_BLOCK
  if not session or session == "" or not block or block == "" or vim.fn.executable("rex") ~= 1 then
    return Snacks.lazygit()
  end
  if opening then
    return
  end
  opening = true
  local cwd = vim.fn.getcwd()

  local function fallback(message)
    opening = false
    vim.notify("Rex LazyGit: " .. message .. "; using Snacks", vim.log.levels.WARN)
    Snacks.lazygit({ cwd = cwd })
  end

  local function call(method, args, callback)
    vim.system(
      { "rex", "--autostart=false", "api", "call", "-s", session, method, vim.json.encode(args) },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          fallback(vim.trim(result.stderr or "request failed"))
          return
        end
        local ok, data = pcall(vim.json.decode, result.stdout)
        if not ok or type(data) ~= "table" then
          fallback("invalid response")
          return
        end
        callback(data)
      end)
    )
  end

  -- Anchor to Neovim's window, not whichever tab happens to be active.
  call("session.describe_block", { block_id = block }, function(data)
    local window = data.block and data.block.window_id
    if not window then
      fallback("editor window not found")
      return
    end
    call("session.new_layer", {
      window_id = window,
      bounds = { 0.025, 0.025, 0.95, 0.95 },
      focus = true,
      layout = {
        block = {
          flavor = "com.superlogical.terminal.shell",
          label = "LazyGit",
          options = { command = { "lazygit" }, cwd = cwd },
        },
      },
    }, function()
      opening = false
    end)
  end)
end

return M
