local ctx = { session_id = "origin", block_id = "block", client_id = "client" }
local base = string.rep("a", 40)
local function check(case)
	local actions, created, queued, commands = {}, {}, {}, {}
	local prompts, randoms = 0, 0
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
		call = function(method, args)
			if method == "block.method" then
				if case.no_cwd then
					return {}
				end
				return { [case.child_cwd and "child" or "foreground"] = { cwd = "/repo/subdir" } }
			end
			assert(method == "session.create", method)
			created[#created + 1] = args
			local options = args.initial_windows[1].layout.block.options
			assert(options.cwd == "/repo" and options.shell == "none")
			assert(options.exit.on_completion == false, "keep failures visible")
			local branch = case.expected or (case.named and "feature/test" or "task-12345678")
			assert(args.label == "repo · " .. branch)
			local expected = {
				"/tool/wt",
				"-C",
				"/repo",
				"switch",
				"--create",
				"--no-cd",
				"--base",
				base,
				"--execute",
				"/bin/zsh",
				branch,
			}
			assert(#expected == #options.command)
			for i, word in ipairs(expected) do
				assert(options.command[i] == word, tostring(options.command[i]))
			end
			if case.create_error then
				return nil, "session creation failed"
			end
			return { session_id = "created", initial_windows = { { window_id = "window" } } }
		end,
		exec = function(args, opts)
			commands[#commands + 1] = args
			assert(opts.timeout == 5)
			if args[1] == "test" then
				return { ok = true, stdout = "" }
			elseif args[1] == "/bin/pwd" then
				assert(opts.cwd == "/repo/subdir")
				return { ok = true, stdout = "/repo/subdir\n" }
			elseif args[1] == "/tool/git" then
				assert(args[2] == "-C")
				if args[4] == "rev-parse" and args[5] == "--show-toplevel" then
					assert(args[3] == "/repo/subdir")
					return { ok = not case.not_repo, stderr = "not a repository", stdout = "/repo\n" }
				end
				assert(args[3] == "/repo")
				if args[4] == "rev-parse" then
					assert(args[5] == "--verify" and args[6] == "HEAD^{commit}")
					return { ok = not case.unborn, stderr = "unknown HEAD", stdout = base .. "\n" }
				elseif args[4] == "check-ref-format" then
					assert(args[5] == "--branch" and args[6] == (case.input or "feature/test"):match("^%s*(.-)%s*$"))
					return { ok = not case.invalid, stderr = "invalid branch", stdout = args[6] .. "\n" }
				elseif args[4] == "show-ref" then
					assert(args[5] == "--verify" and args[6] == "--quiet")
					if case.ref_error then
						return { ok = false, code = 128, stderr = "ref failure" }
					end
					local exists = case.exists or (case.collision and args[7] == "refs/heads/task-12345678")
					return { ok = exists == true, code = exists and 0 or 1 }
				end
				error(table.concat(args, " "))
			elseif args[1] == "/tool/wt" then
				assert(#args == 2 and args[2] == "--version", "no worktree mutation in hidden rex.exec")
				if case.wt_missing then
					return nil, "wt missing"
				end
				return { ok = true, stdout = "wt 1.0\n" }
			elseif args[1] == "/tool/uuidgen" then
				randoms = randoms + 1
				if case.uuid_error then
					return nil, "uuid missing"
				end
				local id = case.collision and randoms > 1 and "ABCDEF12" or "12345678"
				return { ok = true, stdout = case.bad_uuid and "bad" or (id .. "-1234-1234-1234-123456789012\n") }
			end
			error("unexpected executable: " .. args[1])
		end,
		client = {
			queue = function(name, args)
				assert(name == "session.select" and args.session_id == "created" and args.window_id == "window")
				queued[#queued + 1] = args
			end,
		},
		ui = {
			pick = function()
				error("no list UI")
			end,
			input = function(options)
				prompts = prompts + 1
				assert(case.named, "instant action must never prompt")
				assert(options.title == "New worktree · repo")
				if case.cancel then
					return nil, "cancelled"
				end
				if case.busy then
					return nil, "busy"
				end
				return case.input or "feature/test"
			end,
		},
	}
	dofile("config/rex/lua/raptor.lua").setup({
		git = "/tool/git",
		wt = "/tool/wt",
		uuidgen = "/tool/uuidgen",
		shell = "/bin/zsh",
	})
	local run = actions[case.named and "raptor_lua_worktree_named" or "raptor_lua_worktree_instant"]
	local ok, result = pcall(run, ctx)
	if case.error then
		assert(not ok and tostring(result):find(case.error, 1, true), tostring(result))
		assert(#queued == 0)
	elseif case.cancel or case.input == "   " then
		assert(ok and result == nil and #queued == 0)
	else
		assert(ok, tostring(result))
		assert(result.session_id == "created" and #created == 1 and #queued == 1)
	end
	assert(#created == (case.created or ((case.error or case.cancel or case.input == "   ") and 0 or 1)))
	if not case.named then
		assert(prompts == 0)
	end
	if case.named then
		assert(randoms == 0)
	end
end
check({})
check({ child_cwd = true })
check({ named = true })
check({ named = true, input = "  feature/test  " })
check({ named = true, cancel = true })
check({ named = true, input = "   " })
check({ named = true, busy = true, error = "busy" })
check({ named = true, invalid = true, error = "invalid branch name" })
check({ named = true, input = "-bad", error = "invalid branch name" })
check({ named = true, input = "@", error = "invalid branch name" })
check({ named = true, input = "bad\nname", error = "invalid branch name" })
check({ named = true, exists = true, error = "branch already exists" })
check({ no_cwd = true, error = "working directory" })
check({ not_repo = true, error = "not a Git working tree" })
check({ unborn = true, error = "HEAD has no commit" })
check({ wt_missing = true, error = "wt missing" })
check({ uuid_error = true, error = "uuid missing" })
check({ bad_uuid = true, error = "invalid random identifier" })
check({ collision = true, expected = "task-abcdef12" })
check({ exists = true, error = "unused random branch name" })
check({ ref_error = true, error = "could not check branch" })
check({ create_error = true, created = 1, error = "session creation failed" })
print(
	"Lua worktrees: passed (instant/named, HEAD base, validation, collisions, cancellation, visible Worktrunk/hooks, retained failures)"
)
