-- BookFinder: one menu for what the map shows. The world map's own Show menu (the game's filter dropdown, where
-- Shortest Path already puts flight masters, routes, boats, lifts, portals, Nearby and Town services) also takes:
--   Quests            Questie's quest givers and objective icons, and OpenMap's quests from every zone
--   Places            OpenMap's dungeons and raids, mailboxes, spirit healers and rare mobs
--   People            party and raid members, friends and guild members (OpenMap)
--   Library books     the books, and their route
--   Your drawings     OpenMap's ink
-- Each was a switch in OpenMap's own menu, or in Questie's map-button menu (not made in BookFinder); OpenMap's menu
-- keeps how the map looks and its tools, and no switch is in two menus (OpenMap's Map/Panel.lua leaves these out).
-- The entries go in through Shortest Path's menu modifier (UI/MenuModifier.lua), which keeps them out of the game's
-- own build path and withdraws them while the gamepad interface is on.
local _, root = ...
local public = root.public
local SPF, OM, BOOKS = root.SPF, root.OpenMap, root.Books
if not (public and SPF) or SPF.__skip or type(SPF.ModifyMenu) ~= "function" or type(SPF.Init) ~= "function" then return end

local function BL(text) return BOOKS and BOOKS.L and BOOKS.L[text] or text end
local function OL(text) return OM and OM.L and OM.L[text] or text end

local function worldmap()
	if not (OM and not OM.__skip and OM.modules) then return end
	local wm = OM.modules.worldmap
	return wm and wm.db and wm or nil
end

local function questie()
	local q = rawget(_G, "Questie")
	return q and q.db and q.db.profile or nil
end
local function questieModule(name)
	local loader = rawget(_G, "QuestieLoader")
	local ok, mod = pcall(function() return loader:ImportModule(name) end)
	return ok and mod or nil
end

-- the entries, in their sections; each { label, get, set } is left out when its part isn't here
local function sections()
	local out = {}
	local wm = worldmap()
	local p = questie()
	-- Quests
	local quests = {}
	if p and public.Active("Questie") then
		quests[#quests + 1] = { "Quest givers",
			function() return p.showAvailableQuests end,
			function()
				p.showAvailableQuests = not p.showAvailableQuests
				local qq = questieModule("QuestieQuest")
				if qq then pcall(qq.ToggleNotes, qq, p.showAvailableQuests) pcall(qq.SmoothReset, qq) end
			end }
		quests[#quests + 1] = { "Objective icons",
			function() return p.enableObjectives end,
			function()
				p.enableObjectives = not p.enableObjectives
				local qq = questieModule("QuestieQuest")
				if qq then pcall(qq.ToggleNotes, qq, p.enableObjectives) pcall(qq.SmoothReset, qq) end
			end }
	end
	if wm and wm.defaults and wm.defaults.allQuests ~= nil then
		quests[#quests + 1] = { OL("Quests from every zone"), function() return wm.db.allQuests end,
			function() wm.db.allQuests = not wm.db.allQuests wm:Refresh() end }
	end
	if #quests > 0 then out[#out + 1] = { title = QUESTS_LABEL or "Quests", rows = quests } end
	-- Places
	if wm then
		local places = {
			{ OL("Dungeons and raids"), function() return wm.db.icons end, function() wm.db.icons = not wm.db.icons wm:Refresh() end },
		}
		local kinds = {}
		for _, k in ipairs(wm.TOWNSFOLK or {}) do kinds[k.key] = k end
		if wm.HasTownsfolk and wm.HasTownsfolk() then
			for _, key in ipairs({ "mailbox", "spirit", "rare" }) do
				local k = kinds[key]
				if k then
					local label = key == "spirit" and OL("Spirit healers") or key == "rare" and OL("Rare mobs") or k.name
					places[#places + 1] = { label, function() return wm.db.townsfolk[key] end,
						function() wm.db.townsfolk[key] = not wm.db.townsfolk[key] wm:RefreshTownsfolk() end }
				end
			end
		end
		out[#out + 1] = { title = OL("Places"), rows = places }
		out[#out + 1] = { title = "People", rows = {
			{ OL("Party and raid members"), function() return wm.db.group end, function() wm.db.group = not wm.db.group wm:Refresh() end },
			{ OL("Friends on the map"), function() return wm.db.friends end, function() wm.db.friends = not wm.db.friends wm:Refresh() end },
			{ OL("Guild members on the map"), function() return wm.db.guild end, function() wm.db.guild = not wm.db.guild wm:Refresh() end },
		} }
	end
	-- Library books
	if BOOKS and not BOOKS.__skip and BOOKS.db then
		out[#out + 1] = { title = BL("Library books"), rows = {
			{ BL("Show on the map"), function() return not BOOKS.db.hidden end,
				function() BOOKS.db.hidden = not BOOKS.db.hidden or nil if BOOKS.Refresh then BOOKS.Refresh() end end },
			{ BL("Optimized route"), function() return BOOKS.db.routeOn and true or false end,
				function() if BOOKS.ToggleRoute then BOOKS.ToggleRoute(not BOOKS.db.routeOn) end end },
		} }
	end
	if wm then
		out[#out + 1] = { rows = {
			{ OL("Your drawings"), function() return wm.db.sketchShown ~= false end,
				function() wm.db.sketchShown = not (wm.db.sketchShown ~= false) wm:Refresh() end },
		} }
	end
	return out
end

local function build(_, rootDescription)
	for _, section in ipairs(sections()) do
		rootDescription:CreateDivider()
		if section.title and rootDescription.CreateTitle then rootDescription:CreateTitle(section.title) end
		for _, r in ipairs(section.rows) do
			local label, get, set = r[1], r[2], r[3]
			rootDescription:CreateCheckbox(label, function()
				local ok, v = pcall(get)
				return ok and v and true or false
			end, function()
				local ok, err = pcall(set)
				if not ok then geterrorhandler()(err) end
			end)
		end
	end
end

-- (once Shortest Path's settings are in: its modifier reads them)
SPF.Init(function() SPF.ModifyMenu("MENU_WORLD_MAP_TRACKING", "bookfinder", build) end)

-- for the offline test: the entries as they would be added
public.MapMenuSections = sections
