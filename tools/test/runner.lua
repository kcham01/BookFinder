-- tools/test/runner.lua: see run.sh. Each test file gets a fresh client: wow.lua, then the add-on, then the test.
--
-- A test file is a list of cases: return { ["name"] = function(BF) ... end, ... }. Each case runs in a fresh world.
-- Helpers available to tests: Fire(event, ...), Tick(seconds), World (see wow.lua), expect(cond, message),
-- equal(actual, expected, message), Login() (fires ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD).

local filter = arg[1]

local function readToc()
	local files = {}
	for line in io.lines("BookFinder/BookFinder.toc") do
		line = line:gsub("\r", "")
		if line ~= "" and not line:match("^#") then
			files[#files + 1] = "BookFinder/" .. line:gsub("\\", "/")
		end
	end
	return files
end

local function testFiles()
	local list = {}
	local p = io.popen("ls tools/test/test_*.lua 2>/dev/null")
	for f in p:lines() do list[#list + 1] = f end
	p:close()
	return list
end

local passed, failed = 0, 0
local helpers = {} -- test helpers, put back into each fresh client
local plainXpcall = xpcall -- wow.lua wraps it the client's way; each client starts from the plain one

local function freshClient()
	-- Every global from the last case goes, except Lua's own.
	local keep = {}
	for _, k in ipairs({ "string", "table", "math", "os", "io", "debug", "coroutine", "package", "pairs", "ipairs",
		"next", "type", "tostring", "tonumber", "select", "error", "assert", "pcall", "xpcall", "setmetatable",
		"getmetatable", "rawget", "rawset", "rawequal", "unpack", "loadstring", "loadfile", "load", "dofile",
		"setfenv", "getfenv", "require", "collectgarbage", "gcinfo", "newproxy", "_G", "_VERSION", "arg" }) do
		keep[k] = true
	end
	setmetatable(_G, nil)
	for k in pairs(_G) do if not keep[k] then _G[k] = nil end end
	xpcall = plainXpcall
	dofile("tools/test/wow.lua")
	for name, fn in pairs(helpers) do rawset(_G, name, fn) end
	local BF = {}
	for _, file in ipairs(readToc()) do
		local chunk, err = loadfile(file)
		if not chunk then error("load " .. file .. ": " .. err, 0) end
		chunk("BookFinder", BF)
	end
	return BF
end

function helpers.expect(cond, message)
	if not cond then error(message or "expectation failed", 2) end
end

function helpers.equal(actual, expected, message)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(message or "value", tostring(expected), tostring(actual)), 2)
	end
end

function helpers.Login()
	Fire("ADDON_LOADED", "BookFinder")
	Fire("PLAYER_LOGIN")
	Fire("PLAYER_ENTERING_WORLD", true, false)
end

-- First: the add-on loads at all.
do
	local ok, err = pcall(freshClient)
	if not ok then
		print("FAIL load: " .. tostring(err))
		os.exit(1)
	end
	print("ok   load: every TOC file")
end

for _, file in ipairs(testFiles()) do
	local cases = dofile(file)
	local names = {}
	for name in pairs(cases) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local label = file:match("test_(.-)%.lua") .. ": " .. name
		if not filter or label:find(filter, 1, true) then
			local BF = freshClient()
			local ok, err = xpcall(function() cases[name](BF) end, debug.traceback)
			if ok and #World.errors > 0 then
				ok, err = false, "handler error: " .. World.errors[1]
			end
			if ok then
				passed = passed + 1
				print("ok   " .. label)
			else
				failed = failed + 1
				print("FAIL " .. label .. "\n     " .. tostring(err):gsub("\n", "\n     "))
			end
		end
	end
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
