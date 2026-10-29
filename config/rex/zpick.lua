-- zpick — sesh-style zoxide picker for Rex.
--
-- Opens a floating fzf over your zoxide list.
--   alt+cmd+p        open the picker
--     enter          open with the default target (switch/create session)
--     ctrl-o         "open as…" chooser: session / tab / pane → / pane ↓ / cd here
--
-- Also usable head-less from the CLI:
--   rex do zpick target=tab dir=~/some/project
--   rex do zpick target=here dir=~/some/project   (cd the current pane)
--   rex do zpick_last                             (jump back / A↔B toggle)

local cfg = {
  -- key that opens the picker
  open_key = "shift+ctrl+n",

  -- popup rectangle, as fractions of the current window (x, y, w, h)
  bounds = { x = 0.20, y = 0.15, w = 0.60, h = 0.70 },

  -- what Enter does: "session" | "tab" | "pane" | "pane_below"
  enter = "session",

  -- key that opens the "open as…" chooser, and the targets it offers
  chooser_key = "ctrl-o",
  targets = { "session", "tab", "pane", "pane_below", "here" },

  -- extra fzf arguments, one string (they are word-split)
  fzf_opts = "",

  -- cap the list length; 0 = everything zoxide knows
  max_entries = 0,

  -- picker script; also reached through ~/.config/rex (symlink)
  script = os.getenv("HOME") .. "/.config/rex/scripts/rex-zpick",
}

-- ---------------------------------------------------------------- actions --

local labels = {
  session    = "session",
  tab        = "tab",
  pane       = "pane \u{2192}",
  pane_below = "pane \u{2193}",
  here       = "cd here",
}

local function basename(p)
  return (p:gsub("(.*/)(.-)$", "%2"))
end

local function write_ctx(ctx, path, direct)
  local header = "enter: " .. (labels[cfg.enter] or cfg.enter)
    .. "   " .. cfg.chooser_key .. ": open as…"

  local f = assert(io.open(path, "w"))
  f:write("SESSION=" .. (ctx.session_id or "") .. "\n")
  f:write("BLOCK=" .. (ctx.block_id or "") .. "\n")
  f:write("CLIENT=" .. (ctx.client_id or "") .. "\n")
  f:write("ENTER=" .. cfg.enter .. "\n")
  f:write("CHOOSER=" .. cfg.chooser_key .. "\n")
  f:write("TARGETS=" .. table.concat(cfg.targets, ",") .. "\n")
  f:write("HEADER=" .. header .. "\n")
  f:write("FZFOPTS=" .. cfg.fzf_opts .. "\n")
  f:write("MAX=" .. tostring(cfg.max_entries) .. "\n")
  f:close()

  if not ctx.session_id then
    error("zpick: no session context; run from a key or inside a session", 0)
  end
  _ = direct
end

rex.action{
  name        = "zpick",
  title       = "Zoxide Picker",
  description = "Fuzzy-find a zoxide directory; open it as a session, tab, or split pane.",
  category    = "Navigate",
  keywords    = "zoxide sesh fzf picker project session switch",
  args        = { target = "string?", dir = "string?" },
  run = function(ctx, args)
    local tmp = os.tmpname()

    -- direct mode: skip the picker, open a known directory
    if args.dir then
      write_ctx(ctx, tmp, true)
      local r, err = rex.exec(
        { cfg.script, "--direct", args.target or cfg.enter, args.dir, tmp },
        { timeout = 20 })
      if r == nil then error(err, 0) end
      if not r.ok then
        error(("zpick script exit %s%s%s"):format(r.code, r.stdout, r.stderr), 0)
      end
      return { target = args.target or cfg.enter, dir = args.dir }
    end

    -- picker mode: floating layer running the script
    write_ctx(ctx, tmp, false)

    -- anchor the picker over the window the user is looking at
    -- (the session's "active" window may differ from the client's view)
    local win_id
    if ctx.block_id then
      local d = rex.session.describe_block{ block_id = ctx.block_id }
      if d ~= nil and d.block ~= nil then win_id = d.block.window_id end
    end

    local layer, err = rex.session.new_layer{
      window_id = win_id,
      bounds = { cfg.bounds.x, cfg.bounds.y, cfg.bounds.w, cfg.bounds.h },
      focus  = true,
      layout = rex.layout.block{
        flavor   = "com.superlogical.terminal.shell",
        options  = {
          command = { cfg.script, tmp },
          shell   = "none",
        },
      },
    }
    if layer == nil then
      os.remove(tmp)
      error(err, 0)
    end

    -- make sure the picker block is focused and its window is shown
    if layer.block_ids ~= nil and layer.block_ids[1] ~= nil then
      rex.session.focus_block{ block_id = layer.block_ids[1] }
    end
    if ctx.client_id ~= nil then
      rex.client.queue("session.select", {
        session_id = ctx.session_id,
        window_id  = win_id,
      })
    end
  end,
}

rex.bind(cfg.open_key, "zpick")

-- jump back to the session the picker last switched you away from (A↔B toggle)
local state_file = (os.getenv("XDG_CACHE_HOME") or os.getenv("HOME") .. "/.cache")
  .. "/rex/zpick-last"

rex.action{
  name        = "zpick_last",
  title       = "Zoxide: Last Session",
  description = "Jump back to the session the picker switched you away from. Press again to toggle back.",
  category    = "Navigate",
  keywords    = "zoxide sesh last session back toggle",
  run = function(ctx, args)
    local f = io.open(state_file, "r")
    if f == nil then error("no previous session recorded yet", 0) end
    local last = f:read("*l")
    f:close()
    if last == nil or last == "" then error("no previous session recorded yet", 0) end

    local r, err = rex.call("session.list")
    if r == nil then error(err, 0) end
    local exists = false
    for _, s in ipairs(r.sessions or {}) do
      if s.session_id == last then exists = true; break end
    end
    if not exists then error("the last session is gone", 0) end

    -- swap: after jumping, "last" becomes where we are now
    if last ~= ctx.session_id and ctx.session_id ~= nil then
      local wf = assert(io.open(state_file, "w"))
      wf:write(ctx.session_id .. "\n")
      wf:close()
    end

    if ctx.client_id ~= nil and (ctx.origin == "key" or ctx.origin == "palette") then
      rex.client.queue("session.select", { session_id = last })
    end
    return { selected = last }
  end,
}
