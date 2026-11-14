-- The Journey tab: My Journey, Quests by Zone, Quests by Faction, Advanced Search.

local function quest(id, title, objectives)
	return { questID = id, title = title, level = 2, objectives = objectives or {} }
end

local function setup()
	World.player.level = 3
	World.completed[783] = true
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	Login()
	Tick(3)
end

local function texts(BF)
	local t = {}
	local content = BF.Panel.frame.content
	for _, c in ipairs(content.children) do
		if c.shown and c.text and c.text.text then t[#t + 1] = c.text.text .. (c.right and c.right.text ~= "" and (" | " .. c.right.text) or "") end
	end
	return table.concat(t, "\n")
end

local function rowWith(BF, fragment)
	for _, c in ipairs(BF.Panel.frame.content.children) do
		if c.shown and c.text and c.text.text and c.text.text:find(fragment, 1, true) then return c end
	end
end

return {
	["the Journey tab appears with its four pages"] = function(BF)
		setup()
		BF.Panel:Show("journey")
		local labels = {}
		for _, t in ipairs(BF.Panel.frame.topTabs) do if t.shown then labels[#labels + 1] = t.page.label end end
		equal(table.concat(labels, ", "), "My Journey, Quests by Zone, Quests by Faction, Advanced Search", "pages")
	end,

	["My Journey: empty at first, then what happens, by level, with notes"] = function(BF)
		setup()
		BF.Panel:Show("journey", "myJourney")
		expect(texts(BF):find("It's about time you embark on your first Journey!", 1, true), "empty")
		World.questLog = { quest(7, "Kobold Camp Cleanup") }
		Fire("QUEST_LOG_UPDATE")
		Tick(1)
		World.questLog = {}
		World.completed[7] = true
		Fire("QUEST_TURNED_IN", 7)
		Fire("QUEST_LOG_UPDATE")
		Tick(1)
		BF.Journey:AddNote("Bought a spade")
		local t = texts(BF)
		expect(t:find("Level 3", 1, true), "by level")
		expect(t:find("Accepted: [2] Kobold Camp Cleanup", 1, true), "accepted")
		expect(t:find("Completed: [2] Kobold Camp Cleanup", 1, true), "handed in")
		expect(t:find("Note: Bought a spade", 1, true), "the note")
		local entries = BF.Journey:Entries()
		BF.Journey:Remove(entries[#entries])
		expect(not texts(BF):find("Bought a spade", 1, true), "note deleted")
	end,

	["Quests by Zone: the player's zone, its quests in their lists"] = function(BF)
		setup()
		BF.Panel:Show("journey", "byZone")
		local t = texts(BF)
		expect(t:find("Available Quests", 1, true), "available")
		expect(t:find("Kobold Camp Cleanup", 1, true), "a Northshire quest")
		expect(t:find("Completed Quests", 1, true), "completed (783)")
		expect(t:find("Missing Requirement", 1, true), "a later quest needs something")
	end,

	["Quests by Zone: a quest opens its details"] = function(BF)
		setup()
		BF.Panel:Show("journey", "byZone")
		local r = rowWith(BF, "Kobold Camp Cleanup")
		r.scripts.OnClick(r, "LeftButton")
		local t = texts(BF)
		expect(t:find("Quest ID: 7", 1, true), "the details")
		expect(t:find("Marshal McBride", 1, true), "started by")
		expect(t:find("Doable", 1, true), "doable")
	end,

	["lists: completed, hidden, missing requirement with its reason"] = function(BF)
		setup()
		equal(BF.QuestsByZone:ListOf(783), "Completed Quests", "783")
		BF.Rules:SetHidden(33, true)
		equal(BF.QuestsByZone:ListOf(33), "Hidden Quests", "hidden by you")
		local list, why = BF.QuestsByZone:ListOf(3905)
		equal(list, "Missing Requirement", "Milly's second quest")
		equal(why, "prerequisite", "needs the first")
	end,

	["Quests by Faction: the factions quests reward"] = function(BF)
		setup()
		local found = false
		for _, f in ipairs(BF.QuestsByZone:Factions()) do if f[1] == 72 then found = f[3] > 10 end end
		expect(found, "Stormwind, with many quests")
	end,

	["Advanced Search: by name and by ID, grouped by kind"] = function(BF)
		setup()
		local r, counts = BF.Search:Find("kobold vermin")
		expect(counts.npcs >= 1, "the NPC")
		r, counts = BF.Search:Find("7")
		equal(r.quests[1][1], 7, "quest 7 by ID first")
		BF.Panel:Show("journey", "search")
		local box = BF.Panel.frame.content.children[1]
		box.text = "Marshal McBride"
		box.scripts.OnTextChanged(box)
		Tick(1)
		local t = texts(BF)
		expect(t:find("NPCs", 1, true) and t:find("Marshal McBride", 1, true), "found")
	end,

	["Advanced Search: an NPC on the map, then off"] = function(BF)
		setup()
		BF.Search:Show("npcs", 197)
		expect(texts(BF):find("NPC ID: 197", 1, true), "the details")
		BF.Search:SetShown("npc", 197, true)
		local found = false
		for _, pin in ipairs(BF.Marks:On(1429)) do
			for _, role in ipairs(pin.roles) do if role.role == "found" then found = true end end
		end
		expect(found, "on the map")
		BF.Search:ClearMap()
		found = false
		for _, pin in ipairs(BF.Marks:On(1429)) do
			for _, role in ipairs(pin.roles) do if role.role == "found" then found = true end end
		end
		expect(not found, "off again")
	end,
}
