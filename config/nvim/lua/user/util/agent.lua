local M = {}

local agents = {
  pi = true,
  codex = true,
  claude = true,
}

local function notify(message, level)
  vim.notify(message, level, { title = "Agent" })
end

local function current_location(is_visual)
  local path = vim.fn.expand("%:p")
  if path == "" then
    return nil
  end

  local first_line = is_visual and vim.fn.line("v") or vim.fn.line(".")
  local last_line = is_visual and vim.fn.line(".") or first_line
  if first_line > last_line then
    first_line, last_line = last_line, first_line
  end

  local location = vim.fn.expand("%:p:.") .. ":" .. first_line
  if last_line ~= first_line then
    location = location .. "-" .. last_line
  end
  return location
end

local function process_name(cmdline)
  for _, command in ipairs(cmdline or {}) do
    local name = vim.fn.fnamemodify(command, ":t")
    if agents[name] then
      return name
    end
  end
end

local function is_same_cwd(window, cwd)
  if window.cwd == cwd then
    return true
  end

  for _, process in ipairs(window.foreground_processes or {}) do
    if process.cwd == cwd then
      return true
    end
  end
  return false
end

local function is_agent_window(window, cwd)
  if not is_same_cwd(window, cwd) then
    return false
  end

  for _, process in ipairs(window.foreground_processes or {}) do
    if process_name(process.cmdline) then
      return true
    end
  end
  return false
end

local function select_agent_window(data, current_id, cwd)
  local windows = {}
  local candidates = {}
  local current

  for _, os_window in ipairs(data) do
    for _, tab in ipairs(os_window.tabs or {}) do
      for _, window in ipairs(tab.windows or {}) do
        local id = tostring(window.id)
        windows[#windows + 1] = window
        if id == current_id then
          current = window
        end
        if is_agent_window(window, cwd) then
          candidates[id] = window
        end
      end
    end
  end

  -- Kitty orders directional neighbors geometrically. The last matching
  -- window to the right is therefore the lowest/rightmost agent pane.
  local function rightmost(direction)
    if not current then
      return nil
    end

    local selected
    for _, id in ipairs(current.neighbors and current.neighbors[direction] or {}) do
      if candidates[tostring(id)] then
        selected = candidates[tostring(id)]
      end
    end
    return selected
  end

  return rightmost("right")
    or rightmost("bottom")
    or (function()
      for index = #windows, 1, -1 do
        local window = candidates[tostring(windows[index].id)]
        if window then
          return window
        end
      end
    end)()
end

local function send_to_agent(message, location, cwd)
  local prompt = string.format("%s (context: %s)\r", message, location)
  local current_id = vim.env.KITTY_WINDOW_ID

  vim.system({ "kitty", "@", "ls", "--match-tab", "state:active" }, { text = true }, function(result)
    -- vim.system callbacks run in a fast event context. Schedule the Kitty
    -- response handling before calling Vim/Lua APIs such as vim.json or vim.fn.
    vim.schedule(function()
      if result.code ~= 0 then
        notify("Could not inspect Kitty windows", vim.log.levels.WARN)
        return
      end

      local ok, data = pcall(vim.json.decode, result.stdout)
      local target = ok and select_agent_window(data, current_id, cwd) or nil
      if not target then
        notify("No Pi, Codex, or Claude pane found for " .. cwd, vim.log.levels.WARN)
        return
      end

      local match = "id:" .. target.id
      vim.system({ "kitty", "@", "focus-window", "--match", match }, { text = true }, function(focus_result)
        vim.schedule(function()
          if focus_result.code ~= 0 then
            notify("Could not focus the agent pane", vim.log.levels.WARN)
            return
          end

          vim.system({ "kitty", "@", "send-text", "--match", match, prompt }, { detach = true })
        end)
      end)
    end)
  end)
end

---@param options? { visual?: boolean }
function M.prompt(options)
  options = options or {}

  if not vim.env.KITTY_WINDOW_ID then
    notify("This requires Kitty", vim.log.levels.WARN)
    return
  end

  local location = current_location(options.visual == true)
  if not location then
    notify("No file is open", vim.log.levels.WARN)
    return
  end

  local cwd = vim.fn.getcwd()
  local max_width = math.max(40, vim.o.columns - 10)
  local width = math.min(math.max(60, vim.fn.strdisplaywidth(location) + 10), max_width)

  Snacks.input.input({
    prompt = "Agent · " .. location,
    expand = false,
    win = {
      style = "input",
      width = width,
      height = 8,
      -- Keep the larger input box docked to the bottom with a small margin.
      row = -1,
      wo = {
        wrap = true,
        linebreak = true,
        breakindent = true,
      },
      keys = {
        -- Snacks normally requires Esc to leave insert mode before its
        -- normal-mode cancel mapping runs. Make the first Esc cancel.
        i_esc = { "<esc>", { "cmp_close", "cancel" }, mode = "i", expr = true },
      },
    },
  }, function(message)
    message = vim.trim(message or "")
    if message == "" then
      return
    end
    send_to_agent(message, location, cwd)
  end)
end

return M
