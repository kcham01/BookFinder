local function kindsOn(BF, map)
	local found = {}
	for _, pin in ipairs(BF.Marks:On(map)) do
		for _, r in ipairs(pin.roles) do
			if r.role == "townsfolk" then found[r.kind.key] = (found[r.kind.key] or 0) + 1 end
		end
	end
	return found
end

return {
	["townsfolk: Questie's defaults in Elwynn (innkeeper, flight master, mailbox)"] = function(BF)
		Login()
		Tick(5)
		local k = kindsOn(BF, 1429)
		expect(k.innkeeper, "an innkeeper in Elwynn (Goldshire)")
		expect(k.mailbox, "a mailbox")
		expect(not k.repair, "repair off by default")
		local sw = kindsOn(BF, 1453) -- Stormwind City
		expect(sw.flightMaster, "a flight master in Stormwind")
	end,

	["townsfolk: switches, class trainers of the player's class only"] = function(BF)
		Login()
		Tick(5)
		BF:Set("townsfolk.classTrainer", true)
		Tick(0.5)
		local sw = kindsOn(BF, 1453)
		expect(sw.classTrainer, "warrior trainers in Stormwind")
		-- No mage trainer is marked for a warrior: every class trainer marked is in the warrior list.
		local warriors = {}
		for _, id in ipairs(BF.Data.townsfolk.classTrainers.WARRIOR) do warriors[id] = true end
		for _, pin in ipairs(BF.Marks:On(1453)) do
			for _, r in ipairs(pin.roles) do
				if r.role == "townsfolk" and r.kind.key == "classTrainer" then
					expect(warriors[pin.source.id], "only warrior trainers, not " .. pin.source.id)
				end
			end
		end
	end,

	["townsfolk: no Horde flight master for an Alliance player"] = function(BF)
		Login()
		Tick(5)
		local ogrimmar = kindsOn(BF, 1454) -- Orgrimmar
		expect(not ogrimmar.flightMaster, "no Horde flight master")
	end,

	["townsfolk: the tooltip names who and what"] = function(BF)
		World.maps = { [1453] = { size = 1500 } }
		Login()
		Tick(5)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1453)
		local pin
		for _, p in ipairs(WorldMapFrame.pins) do
			if p.pin and p.pin.roles[1] and p.pin.roles[1].role == "townsfolk" and p.pin.roles[1].kind.key == "flightMaster" then pin = p end
		end
		expect(pin, "a flight master pin on the Stormwind map")
		pin:OnMouseEnter()
		local text = table.concat(GameTooltip.lines, "\n")
		expect(text:find("Gryphon Master", 1, true) or text:find("Flight Master", 1, true), "what: " .. text)
	end,
}
