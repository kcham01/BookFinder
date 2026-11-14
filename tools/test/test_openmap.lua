-- OpenMap's side: map pins (with OpenMap's sharing) and friends and guild on the map (OpenMapLoc).

local function setup()
	World.maps = {
		[1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 },
		[1415] = { size = 30000, mapID = 1415, name = "Eastern Kingdoms", mapType = 2 },
	}
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	Login()
	Tick(2)
end

local function pinsOf(template)
	local list = {}
	for _, p in ipairs(WorldMapFrame.pins) do if p.template == template then list[#list + 1] = p end end
	return list
end

return {
	["Ctrl-click the map: a pin, followed, its card open; on the map"] = function(BF)
		setup()
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		World.cursorX, World.cursorY = 0.3, 0.6
		World.ctrl = true
		WorldMapFrame.ScrollContainer.scripts.OnMouseUp(WorldMapFrame.ScrollContainer, "LeftButton")
		World.ctrl = false
		local list = BF.UserPins:List()
		equal(#list, 1, "a pin")
		equal(list[1].x, 0.3, "where clicked")
		expect(World.waypoint and World.waypoint.uiMapID == 1429, "followed: the game's map pin")
		expect(BookFinderPinCard.shown, "its card open")
		BookFinderPinCard.note:SetText("Ore here")
		BookFinderPinCard.done.scripts.OnClick(BookFinderPinCard.done)
		equal(list[1].note, "Ore here", "the note kept")
		Tick(0.2)
		equal(#pinsOf("BookFinderUserPinTemplate"), 1, "drawn on the map")
	end,

	["sharing: OpenMap's message, at most 255 bytes"] = function(BF)
		setup()
		World.group = { "Bob Builder" }
		local p = BF.UserPins:Add(1429, 0.3, 0.6, "Ore here", 3)
		BF.UserPins:Share({ p }, "group")
		local m = World.sentMessages[#World.sentMessages]
		equal(m[1], "OpenMap", "prefix")
		equal(m[2], "P1\t1429\t0.3000\t0.6000\t3\tOre here", "the message")
		equal(m[3], "PARTY", "to the party")
		local long = BF.UserPins:Add(1429, 0.1, 0.1, string.rep("é", 100), 1)
		expect(#BF.UserPins:Message(long) <= 255, "cut to 255 bytes")
	end,

	["codes: written and read back (with the characters a note must escape)"] = function(BF)
		setup()
		local a = BF.UserPins:Add(1429, 0.3, 0.6, "50%, then; left", 2)
		local code = BF.UserPins:Code({ a })
		equal(code, "OMPINS1:1429,0.3000,0.6000,2,50%25%2C then%3B left", "the code")
		local back = BF.UserPins:FromCode("look: " .. code)
		equal(back[1].note, "50%, then; left", "read back")
		equal(BF.UserPins:AddAll(back, "a code"), 0, "the same pin is not added twice")
	end,

	["a pin someone shares: gathered, then asked"] = function(BF)
		setup()
		local asked
		StaticPopup_Show = function(which, text, _, data) asked = { which, text, data } end
		Fire("CHAT_MSG_ADDON", "OpenMap", "P1\t1429\t0.5000\t0.5000\t4\tMeet here", "WHISPER", "Ola Openmap-Forever")
		Tick(2)
		equal(asked and asked[1], "BOOKFINDER_PINS_SHARED", "asked")
		expect(asked[2]:find("Ola Openmap shared 1 map pin(s) with you:", 1, true), asked[2])
		StaticPopupDialogs.BOOKFINDER_PINS_SHARED.OnAccept(nil, asked[3])
		equal(BF.UserPins:List()[1].from, "Ola Openmap", "added, with who shared it")
	end,

	["sharing your place: off by default; on, L1 to the guild, never from an instance"] = function(BF)
		World.guild = { { name = "Gil Guildmate", level = 20, area = "Elwynn Forest", online = true, class = "MAGE" } }
		setup()
		Tick(3)
		for _, m in ipairs(World.sentMessages) do expect(m[1] ~= "OpenMapLoc" or m[2]:sub(1, 2) == "H1", "nothing while off") end
		BF:Set("map.friendsShare", true)
		Tick(3)
		local last
		for _, m in ipairs(World.sentMessages) do if m[1] == "OpenMapLoc" then last = m end end
		equal(last[2], "L1\t1429\t0.4800\t0.4200\tWARRIOR\t10", "the place")
		equal(last[3], "GUILD", "to the guild")
		World.instance = true
		Tick(3)
		for _, m in ipairs(World.sentMessages) do if m[1] == "OpenMapLoc" then last = m end end
		equal(last[2], "L0", "stopped in an instance")
	end,

	["a guild member's place: a dot in their class colour; a zone badge for others"] = function(BF)
		World.guild = {
			{ name = "Gil Guildmate", level = 20, area = "Elwynn Forest", online = true, class = "MAGE" },
			{ name = "Rae Roster", level = 30, area = "Elwynn Forest", online = true, class = "WARRIOR" },
		}
		setup()
		Tick(2)
		Fire("CHAT_MSG_ADDON", "OpenMapLoc", "L1\t1429\t0.4000\t0.5000\tMAGE\t20", "GUILD", "Gil Guildmate-Forever")
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		Tick(1)
		local dots = pinsOf("BookFinderPersonPinTemplate")
		equal(#dots, 1, "Gil's dot")
		equal(dots[1].Icon.color[3], 0.92, "mage blue")
		BF:Set("map.guild", false)
		Tick(1)
		equal(#pinsOf("BookFinderPersonPinTemplate"), 0, "the switch takes them away")
	end,
}
