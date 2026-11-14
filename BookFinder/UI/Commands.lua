-- Slash commands: /bookfinder or /bf, with the things Questie's and Books on map's commands did, in one place.
--   /bf                      the settings
--   /bf help                 this list
--   /bf journey              My Journey          /bf search <words>   Advanced Search
--   /bf books                the Books tab       /bf route            the books route on or off
--   /bf toggle               quest icons on the map on or off
--   /bf tomap <NPC or object name or ID> | tomap reset     put it on the map (no name: the target)
--   /bf flex                 how many quests the player has done
--   /bf eligible <quest ID>  whether the player can take a quest, and if not why
--   /bf minimap              the minimap button on or off
--   /bf version              BookFinder's version
-- (/bom opens the Books tab, as Books on map's command did: Books/Tab.lua.)

local _, BF = ...
local L = BF.L

local Commands = {}
BF.Commands = Commands

local HELP = {
	{ "", "the settings" }, { "journey", "My Journey" }, { "search <words>", "Advanced Search" },
	{ "books", "the library books" }, { "route", "the books route on or off" },
	{ "toggle", "quest icons on the map on or off" },
	{ "tomap <name or ID>", "put an NPC or object on the map (no name: your target)" }, { "tomap reset", "take them off" },
	{ "flex", "how many quests you have done" }, { "eligible <quest ID>", "whether you can take a quest" },
	{ "minimap", "the minimap button on or off" }, { "draw", "the quill: draw on the map" },
	{ "version", "BookFinder's version" },
}

local function help()
	BF:Print(L["commands:"])
	for _, h in ipairs(HELP) do DEFAULT_CHAT_FRAME:AddMessage(("   /bf %s - %s"):format(h[1], L[h[2]])) end
end

-- An NPC or object by ID or (part of) its name; the target when none is given.
local function findSource(text)
	text = strtrim(text or "")
	if text == "" then
		local kind, id = BF.Tooltips:ParseGUID(UnitGUID("target"))
		if kind then return kind, id end
		return nil
	end
	local id = tonumber(text)
	if id then
		if BF:Npc(id) then return "npc", id end
		if BF:Object(id) then return "object", id end
		return nil
	end
	local results = BF.Search:Find(text)
	local needle = text:lower()
	for _, k in ipairs({ { "npcs", "npc" }, { "objects", "object" } }) do
		for _, e in ipairs(results[k[1]] or {}) do
			if e[2] and e[2]:lower() == needle then return k[2], e[1] end
		end
	end
	local first = (results.npcs or {})[1]
	if first then return "npc", first[1] end
	first = (results.objects or {})[1]
	if first then return "object", first[1] end
	return nil
end

local handlers = {
	help = help,
	journey = function() BF.Panel:Show("journey", "myJourney") end,
	search = function(rest) BF.Search:Query(rest) end,
	books = function() BF.BooksTab:Open() end,
	route = function() BF.BookRoute:Toggle() end,
	toggle = function() BF:Toggle("quests.map") BF:Print(BF:Get("quests.map") and L["Quest icons on the map: on."] or L["Quest icons on the map: off."]) end,
	tomap = function(rest)
		if strtrim(rest) == "reset" then
			BF.Search:ClearMap()
			BF:Print(L["Taken off the map."])
			return
		end
		local kind, id = findSource(rest)
		if not kind then
			BF:Print(L["Nothing found by that name."])
			return
		end
		BF.Search:SetShown(kind, id, true)
		BF:Print(L["%s is on the map."], BF.Objectives:SourceName({ type = kind, id = id }) or id)
	end,
	flex = function()
		local n = 0
		for _ in pairs(BF.Player.completed) do n = n + 1 end
		BF:Print(L["You have completed %d quests."], n)
	end,
	eligible = function(rest)
		local id = tonumber(rest)
		if not id or not BF:Quest(id) then BF:Print(L["No such quest."]) return end
		local why = BF.Rules:Blocker(id)
		if not why then BF:Print(L["You can take %s."], BF.Rules:TitleWithLevel(id))
		else BF:Print(L["You can't take %s: %s."], BF.Rules:TitleWithLevel(id), L[BF.Search.REASONS[why] or why]) end
	end,
	minimap = function() BF:Toggle("minimap.button") end,
	version = function() BF:Print("%s", BF.version or "?") end,
	draw = function() BF.Quill:Start() end,
	-- Whether the game finds its minimap pictures by name (the seamless map's minimap detail depends on it): tries a few
	-- names, says which the game knows, and keeps the answer for the owner's SavedVariables.
	probe = function()
		local tex = UIParent:CreateTexture()
		local found = {}
		for _, map in ipairs({ "Azeroth", "Kalimdor", "azeroth", "kalimdor" }) do
			for _, form in ipairs({ "World\\Minimaps\\%s\\map%d_%d", "World\\Minimaps\\%s\\map%d_%d.blp",
				"world/minimaps/%s/map%d_%d.blp" }) do
				local path = form:format(map, 32, 48)
				tex:SetTexture(path)
				local id = tex.GetTextureFileID and tex:GetTextureFileID()
				found[#found + 1] = { path, id or false }
				BF:Print("%s -> %s", path, id and tostring(id) or L["not found"])
			end
		end
		BF:AccountState("probe").minimap = found
		BF:Print(L["Kept in SavedVariables/BookFinder.lua: please send it."])
	end,
}

function Commands:Run(input)
	input = strtrim(input or "")
	local word, rest = input:match("^(%S*)%s*(.-)$")
	word = (word or ""):lower()
	if word == "" then BF.Panel:Toggle() return end
	local fn = handlers[word]
	if fn then fn(rest or "") else help() end
end

BF:At("login", function()
	SLASH_BOOKFINDER1, SLASH_BOOKFINDER2 = "/bookfinder", "/bf"
	SlashCmdList.BOOKFINDER = function(input) Commands:Run(input) end
end, 95)
