return {
	["events reach every handler, even when one removes itself"] = function(BF)
		local calls = {}
		local a
		a = BF:On("TEST_EVENT", function() calls[#calls + 1] = "a"; BF:Off("TEST_EVENT", a) end)
		BF:On("TEST_EVENT", function() calls[#calls + 1] = "b" end)
		Fire("TEST_EVENT")
		Fire("TEST_EVENT")
		equal(table.concat(calls, ","), "a,b,b", "order")
	end,

	["a handler that errors does not stop the others"] = function(BF)
		local reached = false
		BF:Listen("BF_TEST", function() error("boom") end)
		BF:Listen("BF_TEST", function() reached = true end)
		BF:Send("BF_TEST")
		expect(reached, "second listener ran")
		equal(#World.errors, 1, "error reported")
		World.errors[1] = nil
	end,

	["stages run in order, late registrations run at once"] = function(BF)
		local seen = {}
		BF:At("login", function() seen[#seen + 1] = "login" end)
		BF:At("load", function() seen[#seen + 1] = "load" end)
		Login()
		BF:At("load", function() seen[#seen + 1] = "late" end)
		equal(table.concat(seen, ","), "load,login,late", "stages")
	end,

	["settings: defaults, changes, only non-defaults stored"] = function(BF)
		BF.Settings:Define("test.size", { default = 20, min = 10, max = 40 })
		BF.Settings:Define("test.on", { default = true })
		Login()
		equal(BF:Get("test.size"), 20, "default")
		local changes = {}
		BF:Listen("BF_SETTING_CHANGED", function(_, key, value, old) changes[#changes + 1] = key .. "=" .. tostring(value) .. "<" .. tostring(old) end)
		BF:Set("test.size", 99)
		equal(BF:Get("test.size"), 40, "clamped")
		BF:Toggle("test.on")
		equal(BF:Get("test.on"), false, "toggled")
		equal(table.concat(changes, " "), "test.size=40<20 test.on=false<true", "messages")
		BF:Set("test.on", true)
		equal(BookFinderDB.profiles.Default["test.on"], nil, "default not stored")
		equal(BookFinderDB.profiles.Default["test.size"], 40, "change stored")
	end,

	["profiles: switch, copy, reset"] = function(BF)
		BF.Settings:Define("test.size", { default = 20 })
		Login()
		BF:Set("test.size", 30)
		BF.Settings:UseProfile("Alt")
		equal(BF:Get("test.size"), 20, "new profile starts at defaults")
		BF.Settings:CopyProfile("Default")
		equal(BF:Get("test.size"), 30, "copied")
		BF.Settings:ResetProfile()
		equal(BF:Get("test.size"), 20, "reset")
		equal(BookFinderDB.characters["Ada Lovelace - Forever"], "Alt", "character remembers profile")
		expect(not BF.Settings:DeleteProfile("Alt"), "cannot delete the profile in use")
	end,

	["data: rows decode and are cached"] = function(BF)
		Login()
		local q = BF:Quest(7)
		equal(q[BF.Q.name], "Kobold Camp Cleanup", "quest name")
		equal(q[BF.Q.startNpcs][1], 197, "started by Marshal McBride")
		expect(BF:Quest(7) == q, "cached")
		equal(BF:NpcName(197), "Marshal McBride", "npc")
		equal(BF:Quest(999999999), nil, "missing quest")
	end,

	["data: faction rows replace base rows"] = function(BF)
		World.player.faction = "Horde"
		Login()
		local horde = BF.Data.override.Horde.quests
		local id = next(horde)
		expect(id, "there are Horde quest rows")
		local expected = loadstring("return " .. horde[id])()[BF.Q.name]
		equal(BF:QuestName(id), expected, "Horde row used")
	end,

	["zones: areas map to uiMaps, instance spawns go to the entrance"] = function(BF)
		Login()
		equal(BF.Zones:UiMapForArea(12), 1429, "Elwynn Forest")
		local points = {}
		-- 209 is Shadowfang Keep (an instance): its spawns show at its entrance in Silverpine Forest (area 130).
		BF.Zones:EachSpawn({ [209] = { { 50, 50 } }, [12] = { { 48.92, 41.61 } } }, function(map, x, y, inside)
			points[#points + 1] = { map, x, y, inside }
		end)
		equal(#points, 3, "inside the keep, at its door, and in Elwynn")
		table.sort(points, function(a, b) return a[1] < b[1] end)
		equal(points[1][1], 310, "Shadowfang Keep's own map")
		equal(points[1][4], nil, "on its own map it is not 'inside'")
		equal(points[2][1], 1421, "Silverpine Forest's map")
		equal(points[2][4], 209, "at the door: marked as inside the keep")
		equal(points[3][1], 1429, "Elwynn")
		expect(math.abs(points[3][2] - 0.4892) < 1e-9, "x in 0..1")
	end,

	["zones: distance and bearing"] = function(BF)
		World.maps = { [1429] = { size = 1000 } }
		World.player.map, World.player.x, World.player.y = 1429, 0.5, 0.5
		Login()
		-- Stand-in geometry: world = map * size, so 0.1 east is 100 yards.
		local d = BF.Zones:DistanceTo(1429, 0.6, 0.5)
		expect(math.abs(d - 100) < 1e-6, "100 yards, got " .. tostring(d))
		equal(BF.Zones:FormatCoords(0.4892, 0.4161), "48.9, 41.6", "coords")
	end,

	["player: masks and completed quests"] = function(BF)
		World.completed[7] = true
		Login()
		expect(BF.Player:RaceAllowed(BF.Data.raceKeys.ALL_ALLIANCE), "human is Alliance")
		expect(not BF.Player:RaceAllowed(BF.Data.raceKeys.ALL_HORDE), "human is not Horde")
		expect(BF.Player:ClassAllowed(BF.Data.classKeys.WARRIOR), "warrior")
		expect(not BF.Player:ClassAllowed(BF.Data.classKeys.MAGE), "not a mage")
		expect(BF.Player:HasCompleted(7), "quest 7 done")
		expect(not BF.Player:HasCompleted(8), "quest 8 not done")
		expect(BF.Player:FriendlyTo("AH") and BF.Player:FriendlyTo("A") and not BF.Player:FriendlyTo("H"), "friendly")
	end,
}
