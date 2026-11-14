-- Cross-check (scratch, not shipped): BookFinder's serializer against Questie's own, byte for byte.
local REF, BFDIR = arg[1], arg[2]
dofile(BFDIR .. "/tools/test/wow.lua") -- bit, strings, the client's stand-ins
setmetatable(_G, nil)
frexp, ldexp, mod = math.frexp, math.ldexp, math.fmod
Questie = { Error = function(...) print("Questie.Error", ...) end }
local modules = {}
QuestieLoader = { CreateModule = function(_, n) modules[n] = modules[n] or {} return modules[n] end,
	ImportModule = function(_, n) modules[n] = modules[n] or {} return modules[n] end }
dofile(REF .. "/Questie/Modules/QuestieStream.lua")
dofile(REF .. "/Questie/Modules/Libs/QuestieSerializer.lua")
local QS = modules.QuestieSerializer
local BF = { L = setmetatable({}, { __index = function(_, k) return k end }) }
BF.On = function() end
assert(loadfile(BFDIR .. "/BookFinder/Comms/QuestieSerial.lua"))("BookFinder", BF)
local Ours = BF.QuestieSerial

local function dump(v, indent)
	if type(v) ~= "table" then return tostring(v) end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local t = {}
	for _, k in ipairs(keys) do t[#t + 1] = tostring(k) .. "=" .. dump(v[k]) end
	return "{" .. table.concat(t, ",") .. "}"
end

local samples = {
	{ name = "quest update", mode = nil, p = { ver = "1.0.0", msgVer = 5, msgId = 1,
		quest = { id = 7, objectives = { { id = 6, typ = "m", ful = 3, req = 10 } } } } },
	{ name = "quest update, done", p = { ver = "12.9.0", msgVer = 5, msgId = 1,
		quest = { id = 18, objectives = { { id = 752, typ = "i", fin = true, ful = 12, req = 12 }, { id = 0, typ = "m", ful = 0, req = 1 } } } } },
	{ name = "remove", p = { ver = "1.0.0", msgVer = 5, msgId = 2, id = 5261 } },
	{ name = "request", p = { ver = "1.0.0", msgVer = 5, msgId = 11 } },
	{ name = "full list v1 (repeated strings: hashes)", p = { ver = "1.0.0", msgVer = 5, msgId = 10, rawQuestList = {
		[7] = { id = 7, objectives = { { id = 6, typ = "m", ful = 3, req = 10 } } },
		[33] = { id = 33, objectives = { { id = 750, typ = "i", ful = 0, req = 8 } } } } } },
	{ name = "full list v2", p = { ver = "12.9.0", msgVer = 5, msgId = 12, { 2, 7, 1, 6, 109, 3, 10, 33, 1, 750, 105, 0, 8 } } },
	{ name = "big numbers", p = { a = 254, b = 300, c = 70000, d = -5, e = -300, f = 1.5, g = 238, h = 237, i = 0 } },
	{ name = "yell (b89)", mode = "b89", p = { ver = "12.9.0", msgId = 13, { 7, 1, 8, 6, 109, 3, 10 } } },
}

local fails = 0
for _, s in ipairs(samples) do
	-- Byte order of key/value pairs follows pairs(), the same for both on the same table: compare exactly.
	local theirs = QS:Serialize(s.p, s.mode)
	local ours = Ours:Write(s.p, s.mode)
	local same = theirs == ours
	local readTheirs = dump(Ours:Read(theirs, s.mode))
	local readOurs = dump(QS:Deserialize(ours, s.mode))
	local want = dump(s.p)
	local ok = same and readTheirs == want and (s.mode == "b89" or readOurs == want)
	if not ok then fails = fails + 1 end
	print((ok and "same " or "DIFF ") .. s.name .. (same and "" or ("\n  theirs " .. theirs:gsub("[%c\128-\255]", function(c) return ("\\%d"):format(c:byte()) end)
		.. "\n  ours   " .. ours:gsub("[%c\128-\255]", function(c) return ("\\%d"):format(c:byte()) end)))
		.. (readTheirs == want and "" or ("\n  we read theirs as " .. readTheirs))
		.. ((s.mode == "b89" or readOurs == want) and "" or ("\n  they read ours as " .. readOurs)))
	if s.mode == "b89" then print("       (Questie reads its own yell as " .. dump(QS:Deserialize(theirs, "b89")) .. ")") end
end
print(fails == 0 and "ALL SAME" or (fails .. " differ"))
