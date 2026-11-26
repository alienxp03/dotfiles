local original_open, original_rename, original_remove = io.open, os.rename, os.remove
local path = "/state/rex/pins.json"
local ctx = { session_id = "a", client_id = "client" }
local function clone(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in pairs(value) do
		result[k] = clone(v)
	end
	return result
end
local function check(case)
	local actions, files, encoded, queued = {}, {}, {}, {}
	local saves, switchers, editors, submitted = 0, 0, 0, false
	if case.initial then
		encoded.fixture = { version = 1, sessions = case.initial }
		files[path] = "fixture"
	end
	if case.corrupt then
		files[path] = "corrupt"
	end
	if case.version then
		encoded.fixture = { version = case.version, sessions = {} }
		files[path] = "fixture"
	end
	local before = files[path]
	io.open = function(name, mode)
		assert(name:sub(1, #path) == path, name)
		if mode == "r" then
			if case.read_error then
				return nil, "Permission denied", 13
			end
			if not files[name] then
				return nil, "No such file or directory", 2
			end
			return {
				read = function()
					return files[name]
				end,
				close = function()
					return true
				end,
			}
		end
		assert(mode == "w" and name ~= path, "writes must stage beside the state file")
		if case.open_error then
			return nil, "Permission denied"
		end
		return {
			write = function(_, value)
				if case.write_error then
					return nil, "disk full"
				end
				files[name] = value
				return true
			end,
			close = function()
				if case.close_error then
					return nil, "close failed"
				end
				return true
			end,
		}
	end
	os.rename = function(from, to)
		assert(to == path and from:sub(1, #path + 5) == path .. ".tmp-")
		if case.rename_error then
			return nil, "rename failed"
		end
		files[to], files[from] = files[from], nil
		saves = saves + 1
		return true
	end
	os.remove = function(name)
		files[name] = nil
		return true
	end
	local selection = case.selection or {}
	local expected = case.expected or {}
	rex = {
		action = function(a)
			actions[a.name] = a.run
		end,
		log = function() end,
		json = {
			encode = function(value)
				local id = "payload:" .. tostring(#encoded + 1)
				encoded[id] = clone(value)
				return id
			end,
			decode = function(value)
				value = value:gsub("\n$", "")
				if not encoded[value] then
					error("invalid JSON")
				end
				return clone(encoded[value])
			end,
		},
		exec = function(argv)
			assert(argv[1] == "mkdir" and argv[2] == "-p" and argv[3] == "/state/rex")
			if case.mkdir_error then
				return nil, "cannot mkdir"
			end
			return { ok = true }
		end,
		call = function(method)
			assert(method == "session.list")
			local list = {
				{ session_id = "a", label = "Alpha" },
				{ session_id = "b", label = case.renamed and "Renamed Beta" or "Beta" },
				{
					session_id = "c",
					label = "Gamma",
				},
			}
			if case.dead_on_save and submitted then
				table.remove(list, 2)
			end
			return { sessions = list }
		end,
		client = {
			queue = function(name, args)
				assert(name == "session.select")
				queued[#queued + 1] = args.session_id
			end,
		},
		ui = {
			pick = function(options)
				if options.title == "Switch session" then
					switchers = switchers + 1
					assert(options.items[#options.items].id == "manage-pins")
					assert(
						#options.items == ((case.dead_on_save and submitted) and 3 or 4),
						"closed pins must not create rows"
					)
					local pins = (switchers == 1 and not case.reloading) and (case.initial or {}) or expected
					local names = {}
					for _, group in ipairs({ true, false }) do
						for _, id in ipairs({ "a", "b", "c" }) do
							if not (id == "b" and case.dead_on_save and submitted) and (pins[id] == true) == group then
								names[#names + 1] = id
							end
						end
					end
					local titles = { a = "Alpha", b = case.renamed and "Renamed Beta" or "Beta", c = "Gamma" }
					for i, id in ipairs(names) do
						assert(options.items[i].title == titles[id], "stable pinned-first ordering")
						assert(options.items[i].icon == (pins[id] and "star" or nil), "only pins get stars")
						assert(options.items[i].detail == (id == "a" and "Current" or nil))
					end
					if case.view_only or case.reloading or switchers > 1 then
						return case.navigate or nil, "cancelled"
					end
					return "manage-pins"
				end
				assert(options.title == "Manage pins")
				editors = editors + 1
				assert(options.multiple == true and options.confirm == "Save pins" and not options.allow_other)
				assert(#options.items == 3)
				for _, row in ipairs(options.items) do
					assert(row.selected == ((case.initial or {})[row.id] == true), "pins must start checked")
				end
				if case.cancel then
					return nil, "cancelled"
				end
				if case.busy then
					return nil, "busy"
				end
				submitted = true
				return selection
			end,
		},
	}
	local function load()
		dofile("config/rex/lua/raptor.lua").setup({ pins_file = path })
		return actions.raptor_lua
	end
	local ok, result = pcall(load(), ctx)
	if case.error then
		assert(not ok and tostring(result):find(case.error, 1, true), tostring(result))
		assert(files[path] == before, "failed updates must preserve existing state")
		assert(#queued == 0)
	else
		assert(ok, tostring(result))
		if not case.view_only and not case.cancel then
			assert(saves == 1 and editors == 1 and switchers == 2)
			local stored = encoded[files[path]:gsub("\n$", "")]
			assert(stored.version == 1)
			for id in pairs(stored.sessions) do
				assert(expected[id], "unexpected saved pin")
			end
			for id in pairs(expected) do
				assert(stored.sessions[id], "missing saved pin")
			end
			-- Reloading the module must read the saved file, not a module-local cache.
			case.reloading = true
			assert(pcall(load(), ctx))
		else
			assert(saves == 0 and files[path] == before)
		end
		if case.navigate then
			assert(queued[1] == "b")
		end
	end
	for name in pairs(files) do
		assert(name == path, "temporary file must be cleaned up")
	end
	io.open, os.rename, os.remove = original_open, original_rename, original_remove
end
check({ view_only = true })
check({ initial = { b = true }, view_only = true })
check({ initial = { b = true }, view_only = true, renamed = true })
check({ initial = { closed = true }, view_only = true })
check({ selection = { "b" }, expected = { b = true } })
check({ selection = { "b", "c" }, expected = { b = true, c = true } })
check({ initial = { b = true, closed = true }, selection = {}, expected = {} })
check({ initial = { b = true }, cancel = true, expected = { b = true } })
check({ selection = { "b" }, dead_on_save = true, expected = {} })
check({ selection = { "b" }, expected = { b = true }, navigate = "row:1" })
check({ selection = { "unknown" }, error = "unknown session" })
check({ corrupt = true, error = "invalid pin state" })
check({ version = 2, error = "invalid pin state" })
check({ read_error = true, error = "cannot read pins" })
check({ initial = { b = true }, selection = { "c" }, mkdir_error = true, error = "cannot mkdir" })
check({ initial = { b = true }, selection = { "c" }, open_error = true, error = "cannot save pins" })
check({ initial = { b = true }, selection = { "c" }, write_error = true, error = "cannot save pins" })
check({ initial = { b = true }, selection = { "c" }, close_error = true, error = "cannot save pins" })
check({ initial = { b = true }, selection = { "c" }, rename_error = true, error = "cannot save pins" })
check({ busy = true, error = "busy" })
print(
	"Lua pins: passed (stable stars/order, multi-select, persistent reload, clear/cancel, stale sessions, atomic save failures)"
)
