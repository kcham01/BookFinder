return {
	["paths: a walking NPC on the map has its patrol path drawn, lit on hover"] = function(BF)
		Login()
		BF.Search:SetOnMap("npc", 54, true)   -- Corina Steele walks a little route in Elwynn
		Tick(1)
		local n = 0
		BF.Paths.EachPath(function(npc) if npc == 54 then n = n + 1 end end)
		expect(n >= 1, "her path is listed")
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		BF.Paths.RefreshMap()
		expect((World.lines or 0) >= 1, "a line drawn")
		BF.Paths:Highlight(54)
		BF:Set("paths.map", false)
		equal(#World.errors, 0, "no errors")
	end,
}
