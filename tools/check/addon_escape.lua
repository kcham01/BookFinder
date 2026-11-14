local REF, BFDIR = arg[1], arg[2]
dofile(BFDIR .. "/tools/test/wow.lua")
setmetatable(_G, nil)
LibStub = setmetatable({ libs = {} }, { __call = function(self, name) return self.libs[name] end })
function LibStub:NewLibrary(name) self.libs[name] = self.libs[name] or {} return self.libs[name] end
function LibStub:GetLibrary(name) return self.libs[name] end
dofile(REF .. "/Questie/Libs/LibDeflate/LibDeflate.lua")
local LD = LibStub.libs.LibDeflate
local BF = { safecall = pcall }
function BF:On() end
assert(loadfile(BFDIR .. "/BookFinder/Comms/Wire.lua"))("BookFinder", BF)
math.randomseed(7)
local fails = 0
for n = 1, 500 do
	local t = {}
	for i = 1, math.random(0, 300) do t[i] = string.char(math.random(0, 255)) end
	local s = table.concat(t)
	if LD:EncodeForWoWAddonChannel(s) ~= BF.Wire.Escape(s) then fails = fails + 1 end
	if BF.Wire.Unescape(LD:EncodeForWoWAddonChannel(s)) ~= s then fails = fails + 1 end
	if LD:DecodeForWoWAddonChannel(BF.Wire.Escape(s)) ~= s then fails = fails + 1 end
end
print(fails == 0 and "escape: 500 random strings, the same both ways" or (fails .. " failures"))
