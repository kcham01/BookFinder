local function quest(id, title, objectives, isComplete)
	return { questID = id, title = title, level = 2, isComplete = isComplete, objectives = objectives or {} }
end
local function obj(text, have, need, kind)
	return { text = text, type = kind or "monster", numFulfilled = have, numRequired = need, finished = have >= need }
end

local function northshire(BF)
	World.player.level = 2
	World.completed[783] = true
	World.questLog = {
		quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 3/10", 3, 10) }),
		quest(5261, "Eagan Peltskinner", {}),
	}
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	Login()
	Tick(5)
end

local function pinsWithRole(map, role, quest)
	local found = {}
	for _, pin in ipairs(map.pins) do
		for _, r in ipairs(pin.pin.roles) do
			if r.role == role and r.quest == quest then found[#found + 1] = pin end
		end
	end
	return found
end

return {
	["world map: pins for givers, turn-ins and objectives"] = function(BF)
		northshire(BF)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		expect(#pinsWithRole(WorldMapFrame, "available", 33) >= 1, "Wolves Across the Border offered")
		expect(#pinsWithRole(WorldMapFrame, "complete", 5261) >= 1, "Eagan Peltskinner turn-in")
		expect(#pinsWithRole(WorldMapFrame, "objective", 7) >= 1, "Kobold Vermin")
		local pin = pinsWithRole(WorldMapFrame, "complete", 5261)[1]
		equal(pin.Icon.texture, "Interface\\GossipFrame\\ActiveQuestIcon", "turn-in icon (no atlas in this client)")
	end,

	["world map: the setting hides them"] = function(BF)
		northshire(BF)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		BF:Set("quests.map", false)
		equal(#WorldMapFrame.pins, 0, "no pins")
	end,

	["tooltip: the NPC in green, the quest and its reward, the hide hint"] = function(BF)
		northshire(BF)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		local pin = pinsWithRole(WorldMapFrame, "available", 33)[1]
		pin:OnMouseEnter()
		local text = table.concat(GameTooltip.lines, "\n")
		expect(text:find("Eagan Peltskinner", 1, true), "the NPC")
		expect(text:find("Wolves Across the Border", 1, true), "the quest")
		expect(text:find("Shift-click to hide", 1, true), "hide hint")
	end,

	["clicks: ctrl sets the map pin, shift asks to hide"] = function(BF)
		northshire(BF)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		local pin = pinsWithRole(WorldMapFrame, "available", 33)[1]
		World.ctrl = true
		pin:OnMouseUp("LeftButton")
		World.ctrl = false
		expect(World.waypoint and World.waypoint.uiMapID == 1429, "map pin set")
		expect(World.superTracked, "tracked")
		local asked
		StaticPopup_Show = function(which, text, _, data) asked = { which, data } end
		World.shift = true
		pin:OnMouseUp("LeftButton")
		World.shift = false
		equal(asked and asked[1], "BOOKFINDER_HIDE_QUEST", "asked")
		StaticPopupDialogs.BOOKFINDER_HIDE_QUEST.OnAccept(nil, asked[2])
		expect(BF.Rules:HiddenByPlayer(33), "hidden")
	end,

	["minimap: pins near the player only"] = function(BF)
		northshire(BF)
		Minimap.width, Minimap.height = 140, 140
		Minimap.shown = true
		BF.MinimapPins.Update()
		local shown = 0
		for _, child in ipairs(Minimap.children) do if child.shown and child.pin then shown = shown + 1 end end
		expect(shown > 0, "something near Northshire")
		World.player.x, World.player.y = 0.05, 0.95 -- far corner of Elwynn
		BF.MinimapPins.Update()
		local after = 0
		for _, child in ipairs(Minimap.children) do if child.shown and child.pin then after = after + 1 end end
		expect(after < shown, ("fewer pins far away (%d -> %d)"):format(shown, after))
	end,

	["minimap: a rotating minimap turns with the player"] = function(BF)
		World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
		World.player.map, World.player.x, World.player.y = 1429, 0.5, 0.5
		Login()
		-- One mark 60 yards north of the player.
		BF.Marks.byMap = { [1429] = { k = { map = 1429, x = 0.5, y = 0.48, roles = { { role = "available", quest = 33 } } } } }
		BF.Marks.version = BF.Marks.version + 1
		Minimap.width, Minimap.height, Minimap.shown = 140, 140, true
		local function placed()
			BF.MinimapPins.Update()
			for _, child in ipairs(Minimap.children) do
				if child.shown and child.pin then return child.points[#child.points][4], child.points[#child.points][5] end
			end
		end
		local x, y = placed()
		expect(math.abs(x) < 0.01 and y > 0, ("north is up when not rotating (%s, %s)"):format(tostring(x), tostring(y)))
		World.cvars.rotateMinimap = "1"
		World.player.facing = math.pi / 2 -- facing west
		x, y = placed()
		expect(x > 0 and math.abs(y) < 0.01, ("facing west, north is to the right (%s, %s)"):format(tostring(x), tostring(y)))
	end,
}
