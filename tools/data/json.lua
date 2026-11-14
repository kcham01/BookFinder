-- tools/data/json.lua: a small JSON writer for the data converter's Lua parts (returns the encode function).
-- Arrays are tables keyed 1..n without holes; anything else is an object with string keys (numbers as text).

local function isArray(t)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
		n = n + 1
	end
	for i = 1, n do if t[i] == nil then return false end end
	return true
end

local encode
local function encodeString(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
		return map[c] or string.format("\\u%04x", c:byte())
	end) .. '"'
end
function encode(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		if v % 1 == 0 and math.abs(v) < 2^53 then return string.format("%d", v) end
		return string.format("%.17g", v)
	end
	if t == "string" then return encodeString(v) end
	if t == "table" then
		if next(v) == nil then return "[]" end
		local out = {}
		if isArray(v) then
			for i = 1, #v do out[i] = encode(v[i]) end
			return "[" .. table.concat(out, ",") .. "]"
		end
		-- Objects keep their keys as strings; numeric keys come back as numbers in convert.py.
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for i, k in ipairs(keys) do out[i] = encodeString(tostring(k)) .. ":" .. encode(v[k]) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	error("cannot encode a " .. t)
end


return encode
