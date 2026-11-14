-- Friends and guild on the map (OpenMap's, docs/study/openmap.md: "Friends and guild", and the OpenMapLoc protocol):
--   - everyone online on the friends list (and Battle.net friends in this game, same faction) and in the guild shows by
--     zone, as the game's lists say: a badge on the zone with who is there (continent and world maps);
--   - those who share where they are (OpenMap or BookFinder users with "Share where you are") show as a dot in their
--     class colour where they stand ("Updated 30 s ago");
--   - with "Share where you are" on, the player's own place goes to the guild and to friends who use OpenMap, the way
--     OpenMap sends it, never from an instance. Off by default.
-- Switches: "Friends on the map", "Guild members on the map" (the Show dropdown), "Share where you are" (Map > More).

local _, BF = ...
local L = BF.L

local People = { roster = {}, live = {}, known = {}, friends = {} }
BF.People = People

local S = BF.Settings
S:Define("map.friends", { default = true, page = "Map/Show", label = "Friends on the map" })
S:Define("map.guild", { default = true, page = "Map/Show", label = "Guild members on the map" })
S:Define("map.friendsShare", { default = false, page = "Map/More", group = "Sharing", label = "Share where you are" })

local PREFIX = "OpenMapLoc"
local SEND_EVERY, STILL_EVERY, GONE_AFTER, MOVED, GAP = 10, 60, 150, 0.002, 0.5

local function key(name)
	if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) or name == "" then return nil end
	return Ambiguate(name, "none")
end

local function me() return UnitName("player") end

-- Sending: one message every 0.5 s; the newest for a destination replaces one still waiting -----------------------

local outbox, order, sending = {}, {}, false
local function sendNext()
	local k = table.remove(order, 1)
	if not k then sending = false return end
	local m = outbox[k]
	outbox[k] = nil
	if m.bn then
		if BNSendGameData then pcall(BNSendGameData, m.bn, PREFIX, m.text) end
	else
		pcall(C_ChatInfo.SendAddonMessage, PREFIX, m.text, m.channel, m.target)
	end
	BF:After(GAP, sendNext)
end

local function send(k, text, channel, target, bn)
	if not outbox[k] then order[#order + 1] = k end
	outbox[k] = { text = text, channel = channel, target = target, bn = bn }
	if not sending then
		sending = true
		sendNext()
	end
end

local function toFriend(name, text)
	local f = People.friends[name]
	if not f then return end
	if f.bn then send(name, text, nil, nil, f.bn) else send(name, text, "WHISPER", f.whisper) end
end

local function broadcast(text)
	local guild = IsInGuild()
	if guild then send("GUILD", text, "GUILD") end
	for name in pairs(People.known) do
		local r = People.roster[name]
		if People.friends[name] and not (guild and r and r.guild) then toFriend(name, text) end
	end
end

-- The player's place --------------------------------------------------------------------------------------------------

local last = { at = -math.huge }
local sharing = false

local function here()
	if IsInInstance() then return nil end
	local map = C_Map.GetBestMapForUnit("player")
	if type(map) ~= "number" or not BF.Zones:MapSize(map) then return nil end
	local pos = C_Map.GetPlayerMapPosition(map, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return nil end
	if type(x) ~= "number" or (x <= 0 and y <= 0) then return nil end
	return map, x, y
end

local function stop()
	if sharing then
		sharing = false
		last = { at = -math.huge }
		broadcast("L0")
	end
end

function People:Tick()
	if not BF:Get("map.friendsShare") then return stop() end
	local map, x, y = here()
	if not map then return stop() end
	local moved = map ~= last.map or math.abs(x - last.x) > MOVED or math.abs(y - last.y) > MOVED
	if GetTime() - last.at < (moved and SEND_EVERY or STILL_EVERY) then return end
	local _, class = UnitClass("player")
	last = { map = map, x = x, y = y, at = GetTime() }
	last.text = ("L1\t%d\t%.4f\t%.4f\t%s\t%d"):format(map, x, y, class or "", UnitLevel("player") or 0)
	sharing = true
	broadcast(last.text)
end

-- Who is online ----------------------------------------------------------------------------------------------------

local function scanGuild(roster)
	if not IsInGuild() or not GetGuildRosterInfo then return end
	for i = 1, GetNumGuildMembers() or 0 do
		local name, _, _, level, _, area, _, _, online, _, class = GetGuildRosterInfo(i)
		local k = online and key(name)
		if k and k ~= me() then roster[k] = { name = k, level = level, area = area, class = class, guild = true } end
	end
end

local function classFile(localized)
	for file, n in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do if n == localized then return file end end
	for file, n in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do if n == localized then return file end end
end

local function scanFriends(roster, friends)
	if C_FriendList and C_FriendList.GetNumFriends then
		for i = 1, C_FriendList.GetNumFriends() or 0 do
			local f = C_FriendList.GetFriendInfoByIndex(i)
			local k = type(f) == "table" and f.connected and key(f.name)
			if k then
				local r = roster[k] or { name = k, level = f.level, area = f.area, class = classFile(f.className) }
				r.friend = true
				roster[k] = r
				friends[k] = friends[k] or { whisper = f.name }
			end
		end
	end
	if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
		local mine = UnitFactionGroup("player")
		for i = 1, BNGetNumFriends() or 0 do
			local a = C_BattleNet.GetFriendAccountInfo(i)
			local g = type(a) == "table" and a.gameAccountInfo
			if type(g) == "table" and g.isOnline and g.clientProgram == (BNET_CLIENT_WOW or "WoW")
				and (not WOW_PROJECT_ID or g.wowProjectID == WOW_PROJECT_ID) and g.factionName == mine then
				local k = key(g.characterName)
				if k and k ~= me() then
					local r = roster[k] or { name = k, level = g.characterLevel, area = g.areaName, class = classFile(g.className) }
					r.friend = true
					roster[k] = r
					friends[k] = { bn = g.gameAccountID } -- Battle.net reaches any realm: used when there
				end
			end
		end
	end
end

function People:Scan()
	local before = {}
	for k in pairs(People.friends) do before[k] = true end
	local roster, friends = {}, {}
	pcall(scanGuild, roster)
	pcall(scanFriends, roster, friends)
	People.roster, People.friends = roster, friends
	-- A friend just online: a hello, to learn whether they share places (they learn the player does).
	for k in pairs(friends) do if not before[k] then toFriend(k, "H1") end end
	BF:Send("BF_PEOPLE_CHANGED")
end

-- Receiving --------------------------------------------------------------------------------------------------------

function People:Heard(name, text, guild)
	local kind, m, x, y, class, level = strsplit("\t", text, 6)
	if People.friends[name] then People.known[name] = true end
	if kind == "H1" or kind == "H2" then
		if kind == "H1" and People.friends[name] then toFriend(name, sharing and last.text or "H2") end
		return
	end
	if not guild and not People.friends[name] then return end -- a whisper only from a friend
	if kind == "L0" then
		People.live[name] = nil
	elseif kind == "L1" then
		m, x, y = tonumber(m), tonumber(x), tonumber(y)
		if not (m and x and y) or x < 0 or x > 1 or y < 0 or y > 1 or not BF.Zones:MapSize(m) then return end
		local r = People.roster[name]
		People.live[name] = { map = m, x = x, y = y, class = class and class:match("^%u+$"), level = tonumber(level),
			guild = guild or (r and r.guild) or false, at = GetTime() }
	else
		return
	end
	BF:Send("BF_PEOPLE_CHANGED")
end

local function onAddon(_, prefix, text, channel, sender)
	if prefix ~= PREFIX or type(text) ~= "string" or (issecretvalue and (issecretvalue(text) or issecretvalue(sender))) then return end
	if channel ~= "GUILD" and channel ~= "WHISPER" then return end
	local name = key(sender)
	if not name or name == me() then return end
	People:Heard(name, text, channel == "GUILD")
end

local function onBattleNet(_, prefix, text, _, id)
	if prefix ~= PREFIX or type(text) ~= "string" or type(id) ~= "number" then return end
	local g = C_BattleNet and C_BattleNet.GetGameAccountInfoByID and C_BattleNet.GetGameAccountInfoByID(id)
	local name = type(g) == "table" and key(g.characterName)
	if not name or name == me() then return end
	People:Heard(name, text, false)
end

--- Who shows: those sharing (not stale), by the switches.
local function shows(r, isFriend, isGuild)
	if isGuild and BF:Get("map.guild") then return true end
	if isFriend and BF:Get("map.friends") then return true end
	return false
end

-- On the world map ---------------------------------------------------------------------------------------------------

local DOT, BADGE = "BookFinderPersonPinTemplate", "BookFinderZoneBadgeTemplate"
local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
People.Provider = Provider

local function classColour(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

-- The zone maps under a continent or the world, by name (the rosters name zones in the client's words).
local zoneMaps = {}
local function zoneByName(parent)
	local t = zoneMaps[parent]
	if t then return t end
	t = {}
	for _, info in ipairs(C_Map.GetMapChildrenInfo(parent, Enum.UIMapType.Zone, true) or {}) do
		if info.name and not t[info.name] then t[info.name] = info.mapID end
	end
	zoneMaps[parent] = t
	return t
end

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(DOT)
	self:GetMap():RemoveAllPinsByTemplate(BADGE)
end

function Provider:RefreshAllData()
	self:RemoveAllData()
	local map = self:GetMap():GetMapID()
	if not map or not (BF:Get("map.friends") or BF:Get("map.guild")) then return end
	local now = GetTime()
	local placed = {}
	for name, p in pairs(People.live) do
		local r = People.roster[name]
		if now - p.at > GONE_AFTER then
			People.live[name] = nil
		elseif shows(r, r and r.friend, p.guild) then
			local x, y = BF.Zones:Translate(p.map, p.x, p.y, map)
			if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
				self:GetMap():AcquirePin(DOT, name, p, x, y)
				placed[name] = true
			end
		end
	end
	-- Badges: on maps above zones, each zone with the online friends and guild members there who do not share.
	local info = C_Map.GetMapInfo(map)
	if not info or not info.mapType or info.mapType >= Enum.UIMapType.Zone then return end
	local byZone = {}
	local zones = zoneByName(map)
	for name, r in pairs(People.roster) do
		if not placed[name] and shows(r, r.friend, r.guild) and r.area then
			local z = zones[r.area]
			if z then
				byZone[z] = byZone[z] or {}
				table.insert(byZone[z], r)
			end
		end
	end
	for zone, list in pairs(byZone) do
		local x, y = BF.Zones:Translate(zone, 0.5, 0.5, map)
		if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
			table.sort(list, function(a, b) return a.name < b.name end)
			self:GetMap():AcquirePin(BADGE, zone, list, x, y)
		end
	end
end

BookFinderPersonPinMixin = CreateFromMixins(MapCanvasPinMixin)
function BookFinderPersonPinMixin:OnLoad() self:SetScalingLimits(1, 1.0, 1.2) end
function BookFinderPersonPinMixin:OnAcquired(name, p, x, y)
	self.name, self.place = name, p
	BF.Icons:Apply(self.Icon, "groupMember")
	self.Icon:SetVertexColor(classColour(p.class))
	self:SetSize(14, 14)
	self:SetPosition(x, y)
end
function BookFinderPersonPinMixin:OnMouseEnter()
	local p = self.place
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddDoubleLine(p.level and p.level > 0 and ("%s  %d"):format(self.name, p.level) or self.name,
		p.guild and L["Guild"] or L["Friend"], classColour(p.class))
	GameTooltip:AddLine(("%s  %s"):format(BF.Zones:MapName(p.map) or "?", BF.Zones:FormatCoords(p.x, p.y)), 1, 1, 1)
	local ago = math.floor(GetTime() - p.at)
	if ago >= 20 then GameTooltip:AddLine(L["Updated %d s ago"]:format(ago), 0.6, 0.6, 0.6) end
	GameTooltip:Show()
end
function BookFinderPersonPinMixin:OnMouseLeave() GameTooltip:Hide() end

BookFinderZoneBadgeMixin = CreateFromMixins(MapCanvasPinMixin)
function BookFinderZoneBadgeMixin:OnLoad() self:SetScalingLimits(1, 1.0, 1.2) end
function BookFinderZoneBadgeMixin:OnAcquired(zone, list, x, y)
	self.zone, self.list = zone, list
	BF.Icons:Apply(self.Icon, "friend")
	self:SetSize(18, 18)
	self:SetPosition(x, y)
end
function BookFinderZoneBadgeMixin:OnMouseEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(BF.Zones:MapName(self.zone) or "", 1, 0.82, 0)
	for i, r in ipairs(self.list) do
		if i > 25 then
			GameTooltip:AddLine(L["... and %d more"]:format(#self.list - 25), 0.6, 0.6, 0.6)
			break
		end
		local tag = r.guild and L["Guild"] or L["Friend"]
		GameTooltip:AddDoubleLine(r.level and r.level > 0 and ("%s  %d"):format(r.name, r.level) or r.name, tag,
			classColour(r.class))
	end
	GameTooltip:Show()
end
function BookFinderZoneBadgeMixin:OnMouseLeave() GameTooltip:Hide() end

local refresh = BF:Debounce(0.3, function()
	if WorldMapFrame and WorldMapFrame:IsShown() then Provider:RefreshAllData() end
end)

local rescan = BF:Debounce(1, function() People:Scan() end)

BF:At("login", function()
	if WorldMapFrame and WorldMapFrame.AddDataProvider then WorldMapFrame:AddDataProvider(Provider) end
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	BF:On("CHAT_MSG_ADDON", onAddon)
	BF:On("BN_CHAT_MSG_ADDON", onBattleNet)
	for _, e in ipairs({ "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE",
		"BN_FRIEND_ACCOUNT_OFFLINE" }) do
		BF:On(e, rescan)
	end
	BF:Listen("BF_PEOPLE_CHANGED", refresh)
	BF:Listen("BF_SETTING_CHANGED", function(_, k, v)
		if k == "map.friends" or k == "map.guild" then refresh() end
		if k == "map.friendsShare" then People:Tick() end
	end)
	-- Rosters while the map is open; the player's place every 2 s while sharing.
	if WorldMapFrame and WorldMapFrame.HookScript then
		WorldMapFrame:HookScript("OnShow", function()
			if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
			if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
			rescan()
		end)
	end
	BF:Every(2, function() People:Tick() end)
	BF:Every(10, refresh)
	rescan()
end, 77)
