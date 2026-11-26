-- Standalone Rex-native session/project launcher. No Raptor binary or state.
-- dofile("/path/to/raptor.lua").setup{ zoxide = "/path/to/zoxide" }
-- Bind named actions directly: raptor_lua (switch), raptor_lua_open (project).
local M = {}
local config = {
	zoxide = "zoxide",
	git = "git",
	wt = "wt",
	uuidgen = "uuidgen",
	shell = os.getenv("SHELL") or "/bin/sh",
}
local remembered = {}
local home = os.getenv("HOME") or ""

local function fail(message)
	error("raptor_lua: " .. tostring(message), 0)
end
local function call(method, args)
	local value, err = rex.call(method, args)
	if value == nil then
		fail(err or (method .. " failed"))
	end
	return value
end
local function exec(argv, options)
	options = options or {}
	options.timeout = options.timeout or 5
	return rex.exec(argv, options)
end
local function text(value)
	return (value or ""):gsub("[%z\1-\31\127]", " ")
end
local function short(path)
	if home ~= "" and path:sub(1, #home + 1) == home .. "/" then
		return "~" .. path:sub(#home + 1)
	end
	return path
end
local function basename(path)
	return path:match("([^/]+)/*$") or path
end
local function sessions()
	return call("session.list", {}).sessions or {}
end
local function canonical(path, base)
	if type(path) ~= "string" or path == "" or path:find("[%z\1-\31\127]") then
		fail("enter an existing directory path")
	end
	if path == "~" then
		path = home
	elseif path:sub(1, 2) == "~/" then
		path = home .. path:sub(2)
	end
	if path:sub(1, 1) ~= "/" then
		if not base then
			fail("use an absolute path or ~/path")
		end
		path = base .. "/" .. path
	end
	local exists = exec({ "test", "-d", path })
	if not exists or not exists.ok then
		fail("directory does not exist: " .. text(path))
	end
	-- Resolve symlinks without a shell. Validate first: Rex falls back from bad cwd.
	local resolved, err = exec({ "/bin/pwd", "-P" }, { cwd = path })
	if not resolved or not resolved.ok then
		fail(err or "cannot resolve directory")
	end
	local result = (resolved.stdout or ""):gsub("\r?\n$", "")
	if result:sub(1, 1) ~= "/" or result:find("[%z\1-\31\127]") then
		fail("invalid directory path")
	end
	return result
end
local function cwd(session_id, block_id)
	if not block_id then
		return nil
	end
	local result = rex.call("block.method", {
		session_id = session_id,
		block_id = block_id,
		method = "process",
	})
	return result and ((result.foreground and result.foreground.cwd) or (result.child and result.child.cwd))
end
local function warn(message)
	rex.log("warn", "raptor_lua: " .. tostring(message))
end

-- Known project paths come from live terminal working directories and this
-- prototype's remembered destinations. Names alone never establish identity.
local function open_projects(live)
	local opened = {}
	for _, session in ipairs(live) do
		local view = rex.call("session.view", { session_id = session.session_id })
		for _, window in ipairs(view and view.windows or {}) do
			local blocks = {}
			if window.focused_block_id then
				blocks[window.focused_block_id] = true
			end
			for _, layer in ipairs(window.layers or {}) do
				for _, block in ipairs(layer.blocks or {}) do
					if block.block_id then
						blocks[block.block_id] = true
					end
				end
			end
			for block_id in pairs(blocks) do
				local path = cwd(session.session_id, block_id)
				if path and path:sub(1, 1) == "/" then
					opened[path:gsub("/+$", "") .. "/"] =
						{ session_id = session.session_id, window_id = window.window_id }
				end
			end
			for path, saved in pairs(remembered) do
				if saved.session_id == session.session_id and saved.window_id == window.window_id then
					opened[path:gsub("/+$", "") .. "/"] = saved
				end
			end
		end
	end
	return opened
end

local function catalog(ctx, mode)
	local entries, seen = {}, {}
	local live = sessions()
	if mode == "sessions" then
		for _, session in ipairs(live) do
			entries[#entries + 1] = {
				kind = "session",
				session_id = session.session_id,
				title = text(session.label or session.session_id),
				detail = session.session_id == ctx.session_id and "Current" or nil,
			}
		end
		return entries
	end
	local opened = open_projects(live)
	local result, err = exec({ config.zoxide, "query", "--list" })
	if result and result.ok then
		for path in (result.stdout or ""):gmatch("[^\r\n]+") do
			local key = path:gsub("/+$", "") .. "/"
			if path:sub(1, 1) == "/" and not path:find("[%z\1-\31\127]") and not seen[key] and not opened[key] then
				seen[key] = true
				entries[#entries + 1] = {
					kind = "dir",
					path = path,
					title = text(basename(path)),
					subtitle = short(path),
				}
			end
		end
	elseif not result or result.code ~= 1 then
		warn(err or (result and result.stderr) or "zoxide unavailable; type a directory path instead")
	end
	return entries
end

local function select_session(id, window_id)
	-- Queue on this action's client, rather than invoking a nested CLI action.
	rex.client.queue("session.select", { session_id = id, window_id = window_id })
	return { session_id = id, window_id = window_id }
end
local function open_directory(ctx, path)
	path = canonical(path, cwd(ctx.session_id, ctx.block_id))
	local live = sessions()
	-- Recheck after the prompt: a project might have opened while it was visible.
	local existing = open_projects(live)[path:gsub("/+$", "") .. "/"]
	if existing then
		remembered[path] = existing
		return select_session(existing.session_id, existing.window_id)
	end
	local created = call("session.create", {
		label = text(basename(path)):sub(1, 128),
		initial_windows = {
			{
				window_label = "shell",
				layout = rex.layout.block({
					flavor = "com.superlogical.terminal.shell",
					options = { cwd = path },
				}),
			},
		},
	})
	if not created.session_id then
		fail("session creation returned no identity; inspect Rex before retrying")
	end
	local window_id = created.initial_windows and created.initial_windows[1] and created.initial_windows[1].window_id
	remembered[path] = { session_id = created.session_id, window_id = window_id }
	local added, err = exec({ config.zoxide, "add", "--", path })
	if not added or not added.ok then
		warn(err or "could not update zoxide")
	end
	return select_session(created.session_id, window_id)
end
local function guard(ctx)
	if ctx.server then
		fail("this prototype only opens sessions on the local Rex server")
	end
	if not ctx.client_id then
		fail("run from a connected Rex app")
	end
	if not rex.ui or not rex.ui.pick then
		fail("requires Rex native UI (API revision 17+)")
	end
end
local function run(ctx, mode)
	guard(ctx)
	local entries = catalog(ctx, mode)
	local rows, by_id = {}, {}
	for index, entry in ipairs(entries) do
		if index > 2000 then
			warn("showing the first 2,000 results")
			break
		end
		local id = "row:" .. index
		by_id[id] = entry
		rows[#rows + 1] = { id = id, title = entry.title, subtitle = entry.subtitle, detail = entry.detail }
	end
	local choice, why, detail = rex.ui.pick({
		title = mode == "sessions" and "Switch session" or "Open project",
		placeholder = mode == "sessions" and "Find an open session" or "Find a project or type ~/path",
		items = rows,
		allow_other = mode == "projects",
	})
	if choice == nil then
		if why ~= "cancelled" then
			fail(tostring(why) .. " " .. (detail or ""))
		end
		return
	end
	if type(choice) == "table" then
		if mode ~= "projects" then
			fail("choose an open session")
		end
		return open_directory(ctx, choice.text)
	end
	local entry = by_id[choice]
	if not entry then
		fail("unknown selection")
	end
	if entry.kind == "dir" then
		return open_directory(ctx, entry.path)
	end
	-- A session may have closed while the palette was open.
	for _, session in ipairs(sessions()) do
		if session.session_id == entry.session_id then
			return select_session(entry.session_id, entry.window_id)
		end
	end
	fail("session has closed; reopen the picker")
end

local function git(repo, ...)
	local argv = { config.git, "-C", repo }
	for _, value in ipairs({ ... }) do
		argv[#argv + 1] = value
	end
	local result, err = exec(argv)
	if not result then
		fail(err or "could not start git")
	end
	return result
end
local function checked_output(result, message)
	if not result.ok then
		fail(message .. ": " .. text(result.stderr or ""))
	end
	return (result.stdout or ""):gsub("\r?\n$", "")
end
local function branch_exists(repo, branch)
	local result = git(repo, "show-ref", "--verify", "--quiet", "refs/heads/" .. branch)
	if result.ok then
		return true
	end
	if result.code ~= 1 then
		fail("could not check branch: " .. text(result.stderr or ""))
	end
	return false
end
local function create_worktree(ctx, named)
	guard(ctx)
	local origin = cwd(ctx.session_id, ctx.block_id)
	if not origin then
		fail("cannot determine the origin pane's working directory")
	end
	origin = canonical(origin)
	local repo = checked_output(git(origin, "rev-parse", "--show-toplevel"), "not a Git working tree")
	if repo == "" then
		fail("not a Git working tree")
	end
	-- Freeze the originating checkout's HEAD, not Worktrunk's default branch.
	local base = checked_output(git(repo, "rev-parse", "--verify", "HEAD^{commit}"), "HEAD has no commit")
	if not base:match("^%x+$") then
		fail("invalid HEAD commit")
	end
	local available, err = exec({ config.wt, "--version" })
	if not available or not available.ok then
		fail(err or "Worktrunk (wt) is unavailable")
	end
	local branch
	if named then
		local why, detail
		branch, why, detail = rex.ui.input({
			title = "New worktree · " .. text(basename(repo)),
			placeholder = "Branch name",
			confirm = "Create worktree",
		})
		if branch == nil then
			if why ~= "cancelled" then
				fail(tostring(why) .. " " .. (detail or ""))
			end
			return
		end
		branch = branch:gsub("^%s+", ""):gsub("%s+$", "")
		if branch == "" then
			return
		end
		if branch:sub(1, 1) == "-" or branch == "@" or branch:find("[%z\1-\31\127]") then
			fail("invalid branch name")
		end
		local validated = checked_output(git(repo, "check-ref-format", "--branch", branch), "invalid branch name")
		if validated ~= branch then
			fail("use a literal branch name, not a checkout shortcut")
		end
		if branch_exists(repo, branch) then
			fail("branch already exists: " .. text(branch))
		end
	else
		for _ = 1, 8 do
			local result, random_error = exec({ config.uuidgen })
			if not result or not result.ok then
				fail(random_error or "cannot generate a random branch name")
			end
			local uuid = (result.stdout or ""):gsub("[\r\n]", ""):lower()
			if not uuid:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
				fail("invalid random identifier")
			end
			local candidate = "task-" .. uuid:sub(1, 8)
			if not branch_exists(repo, candidate) then
				branch = candidate
				break
			end
		end
		if not branch then
			fail("could not find an unused random branch name")
		end
	end
	-- Worktrunk owns creation, path templates and approvals. Run it in the new
	-- terminal, never a hidden rex.exec: hook output/errors stay visible. Only
	-- success starts a shell in the destination; failed panes remain readable.
	local created = call("session.create", {
		label = text(basename(repo) .. " · " .. branch):sub(1, 128),
		initial_windows = {
			{
				window_label = branch:sub(1, 128),
				layout = rex.layout.block({
					flavor = "com.superlogical.terminal.shell",
					options = {
						cwd = repo,
						shell = "none",
						exit = { on_completion = false },
						command = {
							config.wt,
							"-C",
							repo,
							"switch",
							"--create",
							"--no-cd",
							"--base",
							base,
							"--execute",
							config.shell,
							branch,
						},
					},
				}),
			},
		},
	})
	if not created.session_id then
		fail("session creation returned no identity; inspect Rex before retrying")
	end
	local window_id = created.initial_windows and created.initial_windows[1] and created.initial_windows[1].window_id
	return select_session(created.session_id, window_id)
end

rex.action({
	name = "raptor_lua_worktree_instant",
	title = "Raptor Lua: Instant Worktree",
	category = "Navigate",
	description = "Create a random task branch from this pane's HEAD, then open a session. Worktrunk hooks run visibly.",
	run = function(ctx)
		return create_worktree(ctx, false)
	end,
})
rex.action({
	name = "raptor_lua_worktree_named",
	title = "Raptor Lua: New Worktree…",
	category = "Navigate",
	description = "Name a new worktree branch from this pane's HEAD, then open a session.",
	run = function(ctx)
		return create_worktree(ctx, true)
	end,
})

rex.action({
	name = "raptor_lua",
	title = "Raptor Lua: Switch Session…",
	category = "Navigate",
	description = "Switch to a live session. No directories or session creation.",
	run = function(ctx)
		return run(ctx, "sessions")
	end,
})
rex.action({
	name = "raptor_lua_open",
	title = "Raptor Lua: Open Project…",
	category = "Navigate",
	description = "Open a zoxide directory as a session, excluding known open project paths.",
	run = function(ctx)
		return run(ctx, "projects")
	end,
})
function M.setup(options)
	for key, value in pairs(options or {}) do
		if config[key] == nil then
			fail("unknown option " .. tostring(key))
		end
		if type(value) ~= "string" or value == "" then
			fail(key .. " must be an executable name/path")
		end
		config[key] = value
	end
	return M
end
return M
