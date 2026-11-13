---@class SPFNamespace
local ns = select(2, ...).SPF; if ns.__skip then return end

-- English phrases are the keys, so a phrase with no translation reads as English.
---@type table<string, string>
local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L = L
