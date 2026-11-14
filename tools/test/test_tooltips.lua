local function logWithKobolds()
	World.player.level = 2
	World.completed[783] = true
	World.questLog = { { questID = 7, title = "Kobold Camp Cleanup", level = 2,
		objectives = { { text = "Kobold Vermin slain: 4/10", type = "monster", numFulfilled = 4, numRequired = 10, finished = false } } } }
end

return {
	["tooltip: a creature the log needs shows the quest and its progress"] = function(BF)
		logWithKobolds()
		Login()
		Tick(1)
		GameTooltip:ClearLines()
		World.postCalls[Enum.TooltipDataType.Unit](GameTooltip, { guid = "Creature-0-1-2-3-6-0000" })
		local text = table.concat(GameTooltip.lines, "\n")
		expect(text:find("Kobold Camp Cleanup", 1, true), "the quest: " .. text)
		expect(text:find("4/10", 1, true), "the progress")
		equal(World.cvars.showQuestTrackingTooltips, "0", "the game's own quest lines off while ours show")
	end,

	["tooltip: a secret GUID is left alone"] = function(BF)
		logWithKobolds()
		Login()
		Tick(1)
		issecretvalue = function(v) return v == "SECRET" end
		GameTooltip:ClearLines()
		World.postCalls[Enum.TooltipDataType.Unit](GameTooltip, { guid = "SECRET" })
		equal(#GameTooltip.lines, 0, "nothing added")
	end,

	["tooltip: a library book says if it is collected"] = function(BF)
		Login()
		GameTooltip:ClearLines()
		World.postCalls[Enum.TooltipDataType.Item](GameTooltip, { id = 203755 })
		expect(table.concat(GameTooltip.lines, "\n"):find("Library book - missing", 1, true), "book line")
	end,

	["nameplate: a marker on a creature the log needs, none on others"] = function(BF)
		logWithKobolds()
		Login()
		Tick(1)
		local plate = CreateFrame("Frame", nil, UIParent)
		World.plates.nameplate1 = plate
		World.units.nameplate1 = "Creature-0-1-2-3-6-0000"
		Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
		local marker
		for _, c in ipairs(plate.children) do marker = c end
		expect(marker and marker.shown, "marker on the Kobold Vermin")
		equal(marker.icon.texture, "Interface\\AddOns\\BookFinder\\Media\\Questie\\slay", "Questie's slay icon")
		local plate2 = CreateFrame("Frame", nil, UIParent)
		World.plates.nameplate2 = plate2
		World.units.nameplate2 = "Creature-0-1-2-3-99999-0000"
		Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
		equal(#plate2.children, 0, "nothing on another creature")
	end,
}
