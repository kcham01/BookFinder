-- The wire: addon messages to and from other players, framed the way AceComm frames them (docs/study/
-- questie-protocol.md, section 1), so messages BookFinder sends read as one message to an addon using AceComm and
-- back. Long messages are split into numbered pieces; sending goes through a queue that keeps within the game's
-- bandwidth (about 800 bytes a second, bursts up to 4000), most urgent first.
--
--   BF.Wire:Listen(prefix, fn(message, channel, sender))   sender: the name shortened the game's way
--   BF.Wire:Send(prefix, text, channel, target?, priority?)   priority "ALERT", "NORMAL" (default), "BULK"
--   BF.Wire.Escape(s) / BF.Wire.Unescape(s)                  the addon-channel escape for binary payloads

local _, BF = ...

local Wire = {}
BF.Wire = Wire

local MAX = 255
local FIRST, NEXT, LAST, ESCAPE = "\001", "\002", "\003", "\004"

-- The addon-channel escape: byte 0 -> 1,2 and byte 1 -> 1,3 (no other byte changes).
function Wire.Escape(s)
	return (s:gsub("[%z\001]", function(c) return c == "\000" and "\001\002" or "\001\003" end))
end

function Wire.Unescape(s)
	local bad = false
	local out = s:gsub("\001(.?)", function(c)
		if c == "\002" then return "\000" elseif c == "\003" then return "\001" end
		bad = true
		return ""
	end)
	if bad then return nil end
	return out
end

-- Sending: a queue per priority, drained within the bandwidth -------------------------------------------------------

local queues = { ALERT = {}, NORMAL = {}, BULK = {} }
local ORDER = { "ALERT", "NORMAL", "BULK" }
local RATE, BURST = 800, 4000
local budget, lastTime = BURST, nil

local drainer = CreateFrame("Frame")
drainer:Hide()

local function drain()
	local now = GetTime()
	if lastTime then budget = math.min(BURST, budget + (now - lastTime) * RATE) end
	lastTime = now
	for _, p in ipairs(ORDER) do
		local q = queues[p]
		while q[1] do
			local m = q[1]
			local cost = #m[2] + #m[1]
			if cost > budget then return true end
			table.remove(q, 1)
			budget = budget - cost
			C_ChatInfo.SendAddonMessage(m[1], m[2], m[3], m[4])
		end
	end
	return false
end

drainer:SetScript("OnUpdate", function(self)
	if not drain() then self:Hide() end
end)

local function enqueue(priority, prefix, text, channel, target)
	local q = queues[priority] or queues.NORMAL
	q[#q + 1] = { prefix, text, channel, target }
	if not drain() then return end
	drainer:Show()
end

--- Sends text under a prefix, split into pieces when it is long (AceComm's way).
function Wire:Send(prefix, text, channel, target, priority)
	priority = priority or "NORMAL"
	local forceSplit = false
	if text:match("^[\001-\009]") then
		if #text + 1 > MAX then forceSplit = true else text = ESCAPE .. text end
	end
	if not forceSplit and #text <= MAX then
		enqueue(priority, prefix, text, channel, target)
		return
	end
	local size = MAX - 1
	enqueue(priority, prefix, FIRST .. text:sub(1, size), channel, target)
	local pos = 1 + size
	while pos + size <= #text do
		enqueue(priority, prefix, NEXT .. text:sub(pos, pos + size - 1), channel, target)
		pos = pos + size
	end
	enqueue(priority, prefix, LAST .. text:sub(pos), channel, target)
end

-- Receiving: pieces joined per prefix + channel + sender ---------------------------------------------------------

local listeners = {} -- [prefix] = { fn, ... }
local spool = {}     -- [prefix \t channel \t sender] = { pieces }

function Wire:Listen(prefix, fn)
	if not listeners[prefix] then
		listeners[prefix] = {}
		C_ChatInfo.RegisterAddonMessagePrefix(prefix)
	end
	table.insert(listeners[prefix], fn)
end

local function deliver(prefix, message, channel, sender)
	for _, fn in ipairs(listeners[prefix]) do BF.safecall(fn, message, channel, sender) end
end

function Wire:Receive(prefix, message, channel, sender)
	if not listeners[prefix] or type(message) ~= "string" or type(sender) ~= "string" then return end
	if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then return end
	sender = Ambiguate and Ambiguate(sender, "none") or sender
	local control, rest = message:match("^([\001-\009])(.*)$")
	if not control then
		deliver(prefix, message, channel, sender)
		return
	end
	local key = prefix .. "\t" .. channel .. "\t" .. sender
	if control == FIRST then
		spool[key] = { rest }
	elseif control == NEXT then
		if spool[key] then table.insert(spool[key], rest) end
	elseif control == LAST then
		local pieces = spool[key]
		if pieces then
			spool[key] = nil
			table.insert(pieces, rest)
			deliver(prefix, table.concat(pieces), channel, sender)
		end
	elseif control == ESCAPE then
		deliver(prefix, rest, channel, sender)
	end
end

BF:On("CHAT_MSG_ADDON", function(_, prefix, message, channel, sender)
	Wire:Receive(prefix, message, channel, sender)
end)
