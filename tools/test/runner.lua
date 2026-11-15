-- tools/test/runner.lua: see run.sh. Each test file gets a fresh client: wow.lua, then the add-on, then the test.
--
-- A test file is a list of cases: return { ["name"] = function(BF) ... end, ... } (and before = fn, run ahead of the
-- add-on's files in every case: other add-ons). Each case runs in a fresh world.
-- Helpers available to tests: Fire(event, ...), Tick(seconds), World (see wow.lua), expect(cond, message),
-- equal(actual, expected, message), Login() (fires ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD).

local filter = arg[1]

-- BF_ADDON_DIR: another copy of the add-on folder to load (the packaged one, OpenMap folded in: tools/package.sh).
local ROOT = os.getenv("BF_ADDON_DIR") or "BookFinder"

-- An XML file's <Script file=> and <Include file=> entries, in order, relative to the XML's own folder.
local function xmlFiles(path, out)
	local dir = path:match("^(.*)/[^/]*$") or "."
	local f = io.open(path)
	if not f then return end
	local text = f:read("*a")
	f:close()
	text = text:gsub("<!%-%-.-%-%->", "")
	for tag, file in text:gmatch("<(%a+)%s+file=\"([^\"]+)\"") do
		file = dir .. "/" .. file:gsub("\\", "/")
		if tag == "Script" then out[#out + 1] = file elseif tag == "Include" then xmlFiles(file, out) end
	end
end

local function readToc()
	local files = {}
	for line in io.lines(ROOT .. "/BookFinder.toc") do
		line = line:gsub("\r", ""):gsub("%s*%[.-%]%s*$", "")
		-- (a locale file loads only in its own client: the stand-in client is English)
		local locale = line:match("Locales[\\/](%a%a%a%a)%.lua$")
		if line ~= "" and not line:match("^#") and not locale then
			local path = ROOT .. "/" .. line:gsub("\\", "/")
			if line:lower():match("%.xml$") then xmlFiles(path, files) else files[#files + 1] = path end
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

local function freshClient(before)
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
	if before then before() end   -- (a case's other add-ons, loaded ahead of BookFinder as the TOC's OptionalDeps)
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
	local before = cases.before
	cases.before = nil
	for name in pairs(cases) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local label = file:match("test_(.-)%.lua") .. ": " .. name
		if not filter or label:find(filter, 1, true) then
			local BF = freshClient(before)
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
