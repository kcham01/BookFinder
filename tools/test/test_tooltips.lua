-- Quest lines on NPC, object and item tooltips; quest icons on nameplates and the target frame.

local function quest(id, title, objectives, isComplete)
	return { questID = id, title = title, level = 2, isComplete = isComplete, objectives = objectives or {} }
end
local function obj(text, have, need, kind)
	return { text = text, type = kind or "monster", numFulfilled = have, numRequired = need, finished = have >= need }
end

-- A level 3 human in Northshire: killing kobolds, collecting bandanas, Eagan's letter to hand in.
local function northshire()
	World.player.level = 3
	World.completed[783] = true
	World.questLog = {
		quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 3/10", 3, 10) }),
		quest(18, "Brotherhood of Thieves", { obj("Red Burlap Bandana: 2/12", 2, 12, "item") }),
		quest(5261, "Eagan Peltskinner", {}),
	}
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	Login()
	Tick(5)
end

local function text(lines) return table.concat(lines, "\n") end
local function guid(npc) return "Creature-0-1-0-12-" .. npc .. "-0000AB12CD" end

return {
	["npc: the quest that needs it and the log's own progress line"] = function()
		northshire()
		local t = text(World.ShowTooltip("Unit", { guid = guid(6) }, "Kobold Vermin"))
		expect(t:find("Kobold Camp Cleanup", 1, true), "the quest")
		expect(t:find("Kobold Vermin slain: 3/10", 1, true), "the progress")
		expect(t:find("[2] Kobold Camp Cleanup", 1, true), "its level")
	end,

	["npc: a drop with its chance"] = function()
		northshire()
		local t = text(World.ShowTooltip("Unit", { guid = guid(38) }, "Defias Thug"))
		expect(t:find("Brotherhood of Thieves", 1, true), "the quest")
		expect(t:find("Red Burlap Bandana: 2/12", 1, true), "the item's progress")
		expect(t:find("%%%)"), "a drop chance")
	end,

	["npc: drop chances follow the setting"] = function(BF)
		northshire()
		BF:Set("tooltips.dropRates", false)
		local t = text(World.ShowTooltip("Unit", { guid = guid(38) }, "Defias Thug"))
		expect(t:find("Red Burlap Bandana: 2/12", 1, true), "still the progress")
		expect(not t:find("%%%)"), "no chance")
	end,

	["npc: a giver's quests and a finished quest to hand in"] = function()
		northshire()
		local t = text(World.ShowTooltip("Unit", { guid = guid(196) }, "Eagan Peltskinner"))
		expect(t:find("Wolves Across the Border", 1, true), "offers Wolves Across the Border")
		expect(t:find("Eagan Peltskinner", 1, true), "takes the letter")
		expect(t:find("(Complete)", 1, true), "marked complete")
	end,

	["npc: nothing when the quest lines are off, the ID when asked"] = function(BF)
		northshire()
		BF:Set("tooltips.enabled", false)
		BF:Set("tooltips.ids.npc", true)
		local lines = World.ShowTooltip("Unit", { guid = guid(6) }, "Kobold Vermin")
		local t = text(lines)
		expect(not t:find("Kobold Camp Cleanup", 1, true), "no quest")
		expect(t:find("NPC ID: 6", 1, true), "the ID")
	end,

	["npc: a finished objective says nothing"] = function()
		World.questLog = { quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 10/10", 10, 10) }) }
		World.completed[783] = true
		World.player.level = 3
		Login()
		Tick(5)
		local t = text(World.ShowTooltip("Unit", { guid = guid(6) }, "Kobold Vermin"))
		expect(not t:find("Kobold Camp Cleanup", 1, true), "done with them")
	end,

	["npc: a secret GUID adds nothing"] = function()
		northshire()
		issecretvalue = function() return true end
		local lines = World.ShowTooltip("Unit", { guid = guid(6) }, "Kobold Vermin")
		equal(#lines, 1, "only the client's own line")
	end,

	["item: the quest that asks for it"] = function()
		northshire()
		local t = text(World.ShowTooltip("Item", { id = 752 }, "Red Burlap Bandana"))
		expect(t:find("Brotherhood of Thieves", 1, true), "the quest")
		expect(t:find("2/12", 1, true), "the progress")
	end,

	["item: a library book's state and set"] = function()
		northshire()
		local t = text(World.ShowTooltip("Item", { id = 203755 }, "Theocritus' Retort"))
		expect(t:find("Library book - missing (Starting set)", 1, true), "missing")
		World.bags[203755] = 1
		t = text(World.ShowTooltip("Item", { id = 203755 }, "Theocritus' Retort"))
		expect(t:find("Library book - collected (Starting set)", 1, true), "collected")
	end,

	["object: found by name when the client gives no ID"] = function()
		northshire()
		table.insert(World.questLog, quest(3904, "Milly's Harvest", { obj("Milly's Harvest: 1/8", 1, 8, "item") }))
		Fire("QUEST_LOG_UPDATE")
		Tick(2)
		-- The world cursor's tooltip: no data, only the object's name as its first line.
		local t = text(World.ShowTooltip("Object", {}, "Milly's Harvest"))
		expect(t:find("Milly's Harvest: 1/8", 1, true), "the crate's quest")
		-- A name no quest of the player's touches adds nothing.
		local lines = World.ShowTooltip("Object", {}, "Crate")
		equal(#lines, 1, "a crate is a crate")
	end,

	["nameplate: a needed mob carries the objective's icon"] = function()
		northshire()
		World.units.nameplate1 = { guid = guid(6) }
		World.nameplates.nameplate1 = CreateFrame("Frame", nil, UIParent)
		Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
		local plate = World.nameplates.nameplate1
		local icon = plate.children[1]
		expect(icon and icon.shown, "an icon")
		equal(icon.texture, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "the skull")
	end,

	["nameplate: none for a mob nobody needs, none in combat"] = function()
		northshire()
		World.units.nameplate1 = { guid = guid(299) }
		World.nameplates.nameplate1 = CreateFrame("Frame", nil, UIParent)
		Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
		expect(not World.nameplates.nameplate1.children[1], "no icon for a young wolf")
		World.units.nameplate2 = { guid = guid(6) }
		World.nameplates.nameplate2 = CreateFrame("Frame", nil, UIParent)
		World.combat = true
		Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
		local icon = World.nameplates.nameplate2.children[1]
		expect(not (icon and icon.shown), "stood down in combat")
		World.combat = false
		Fire("PLAYER_REGEN_ENABLED")
		Tick(1)
		icon = World.nameplates.nameplate2.children[1]
		expect(icon and icon.shown, "back after the fight")
	end,

	["nameplate: the icon goes when the objective is done"] = function()
		northshire()
		World.units.nameplate1 = { guid = guid(6) }
		World.nameplates.nameplate1 = CreateFrame("Frame", nil, UIParent)
		Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
		World.questLog[1] = quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 10/10", 10, 10) })
		Fire("QUEST_LOG_UPDATE")
		Tick(2)
		local icon = World.nameplates.nameplate1.children[1]
		expect(icon and not icon.shown, "gone")
	end,

	["target frame: the icon on a needed target"] = function()
		northshire()
		World.units.target = { guid = guid(38) }
		Fire("PLAYER_TARGET_CHANGED")
		local holder = TargetFrame.children[1]
		local icon = holder and holder.children[1]
		expect(icon and icon.shown, "an icon")
		equal(icon.texture, "Interface\\GroupFrame\\UI-Group-MasterLooter", "the loot bag")
		World.units.target = nil
		Fire("PLAYER_TARGET_CHANGED")
		expect(not icon.shown, "gone with the target")
	end,
}
