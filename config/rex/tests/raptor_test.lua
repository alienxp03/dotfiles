local ctx = { session_id = "origin", block_id = "block", client_id = "client" }
local function check(case)
	local actions, queued, commands, rows = {}, {}, {}, nil
	local picked, creates = false, 0
	local live = { { session_id = "origin", label = "Origin" }, { session_id = "existing", label = "app" } }
	rex = {
		action = function(a)
			actions[a.name] = a.run
		end,
		layout = {
			block = function(b)
				return { block = b }
			end,
		},
		log = function() end,
		client = {
			queue = function(name, args)
				assert(name == "session.select")
				queued[#queued + 1] = args
			end,
		},
		call = function(method, args)
			if method == "session.list" then
				if case.list_error then
					return nil, "listing failed"
				end
				if case.stale and picked then
					return { sessions = {} }
				end
				return { sessions = live }
			elseif method == "session.view" then
				return {
					windows = {
						{
							window_id = "window:" .. args.session_id,
							focused_block_id = "block:" .. args.session_id,
							layers = { { blocks = { { block_id = "extra:" .. args.session_id } } } },
						},
					},
				}
			elseif method == "block.method" then
				local path = (case.cwd or {})[args.block_id]
				if case.race and picked and args.block_id == "block:existing" then
					path = "/projects/app"
				end
				return { foreground = { cwd = path or "/origin" } }
			elseif method == "session.create" then
				creates = creates + 1
				assert(args.initial_windows[1].layout.block.options.cwd == "/projects/app")
				if case.create_error then
					return nil, "creation failed"
				end
				return { session_id = "new", initial_windows = { { window_id = "window:new" } } }
			end
			error(method)
		end,
		exec = function(args, opts)
			commands[#commands + 1] = args
			assert(opts.timeout == 5)
			if args[1] == "/tool/zoxide" then
				if case.missing then
					return nil, "missing zoxide"
				end
				if args[2] == "query" then
					return { ok = true, stdout = case.directories or "/projects/app\n/projects/app/\n/personal/app\n" }
				end
				assert(args[2] == "add" and args[3] == "--" and args[4] == "/projects/app")
			elseif args[1] == "test" then
				return { ok = not case.invalid }
			elseif args[1] == "/bin/pwd" then
				assert(opts.cwd == (case.expected_path or "/projects/app"))
				return { ok = true, stdout = "/projects/app\n" }
			else
				error("unexpected executable: " .. args[1])
			end
			return { ok = true, stdout = "" }
		end,
		ui = {
			pick = function(options)
				rows = options.items
				picked = true
				assert(#rows <= 2000)
				if case.projects then
					assert(options.title == "Open project" and options.allow_other == true)
					for _, r in ipairs(rows) do
						assert(r.subtitle and r.icon == nil and r.detail == nil)
					end
					if case.excluded then
						assert(
							#rows == 1 and rows[1].subtitle == "/personal/app",
							"open path must be excluded, same basename must stay"
						)
					elseif not case.missing and not case.directories then
						assert(#rows == 2 and rows[1].subtitle == "/projects/app")
					end
				else
					assert(options.title == "Switch session" and options.allow_other == false)
					assert(#rows == 2 and rows[1].title == "Origin" and rows[1].detail == "Current")
					assert(rows[2].title == "app" and rows[2].subtitle == nil)
				end
				return case.choice, case.why
			end,
		},
	}
	dofile("config/rex/lua/raptor.lua").setup({ zoxide = "/tool/zoxide" })
	assert(actions.raptor_lua_search == nil)
	local run = actions[case.projects and "raptor_lua_open" or "raptor_lua"]
	local ok, result = pcall(run, case.remote and { server = "remote", client_id = "C" } or ctx)
	if case.error then
		assert(not ok and tostring(result):find(case.error, 1, true), tostring(result))
		assert(#queued == 0)
	else
		assert(ok, tostring(result))
		if case.selected then
			assert(#queued == 1 and queued[1].session_id == case.selected)
			assert(result.session_id == case.selected)
			if case.window then
				assert(queued[1].window_id == case.window)
			end
		else
			assert(#queued == 0)
		end
	end
	assert(creates == (case.creates or 0))
	if not case.projects then
		assert(#commands == 0, "switch action must not run zoxide or create directories")
	end
	if case.count then
		assert(#rows == case.count)
	end
end
check({ choice = "row:2", selected = "existing" })
check({ why = "cancelled" })
check({ why = "busy", error = "busy" })
check({ choice = "row:2", stale = true, error = "session has closed" })
check({ choice = { text = "/projects/app" }, error = "choose an open session" })
check({ list_error = true, error = "listing failed" })
check({ remote = true, error = "local Rex server" })
check({ projects = true, choice = "row:1", selected = "new", window = "window:new", creates = 1 })
check({ projects = true, why = "cancelled", excluded = true, cwd = { ["block:existing"] = "/projects/app" } })
check({ projects = true, why = "cancelled", excluded = true, cwd = { ["extra:existing"] = "/projects/app/" } })
check({ projects = true, choice = "row:1", race = true, selected = "existing", window = "window:existing" })
check({
	projects = true,
	choice = { text = "/projects/app" },
	cwd = { ["block:existing"] = "/projects/app" },
	excluded = true,
	selected = "existing",
	window = "window:existing",
})
check({
	projects = true,
	choice = { text = "~/app" },
	expected_path = os.getenv("HOME") .. "/app",
	selected = "new",
	creates = 1,
})
check({ projects = true, choice = { text = "./app" }, expected_path = "/origin/./app", selected = "new", creates = 1 })
check({ projects = true, choice = { text = "/bad\npath" }, error = "existing directory path" })
check({ projects = true, choice = "row:1", invalid = true, error = "does not exist" })
check({ projects = true, choice = "row:1", create_error = true, error = "creation failed", creates = 1 })
check({ projects = true, missing = true, why = "cancelled", count = 0 })
check({ projects = true, missing = true, choice = { text = "/projects/app" }, selected = "new", creates = 1 })
local many = {}
for i = 1, 2100 do
	many[#many + 1] = "/projects/p" .. i
end
check({ projects = true, directories = table.concat(many, "\n"), why = "cancelled", count = 2000 })
print(
	"Lua-only launcher: passed (separate session/project pickers, zoxide, open-path exclusion, same-name safety, creation race, typed paths, failures)"
)
