local function open()
	World.mapRects = { ["1415:947"] = { 0.6, 0.9, 0.2, 0.8 }, ["1429:947"] = { 0.7, 0.75, 0.6, 0.65 }, ["1429:1415"] = { 0.33, 0.5, 0.67, 0.75 } }
	World.maps = { [947] = { mapType = 1, size = 100000, name = "Azeroth" }, [1415] = { mapType = 2, size = 50000, name = "Eastern Kingdoms", parentMapID = 947 },
		[1429] = { mapType = 3, size = 3000, name = "Elwynn Forest", parentMapID = 1415 } }
	World.mapChildren = { [947] = { 1415 }, [1415] = { 1429 } }
	WorldMapFrame.mapID = 1429
	WorldMapFrame.ScrollContainer.width, WorldMapFrame.ScrollContainer.height = 1000, 667
end

return {
	["seamless: opens on the zone, its art in place"] = function(BF)
		open()
		Login()
		WorldMapFrame:Show()
		local view = BookFinderSeamlessMap
		view.width, view.height = 1000, 667
		BF.Seamless:ShowMap(1429, true)
		local st = BF.Seamless.State
		expect(math.abs(st.u - 0.725) < 1e-6 and math.abs(st.v - 0.625) < 1e-6, "centred on Elwynn")
		expect(st.zoom > 10, "zoomed in on a zone, got " .. st.zoom)
	end,

	["seamless: wheel zooms toward the cursor, right-click steps out"] = function(BF)
		open()
		Login()
		WorldMapFrame:Show()
		local view = BookFinderSeamlessMap
		view.width, view.height = 1000, 667
		BF.Seamless:FlyTo(0.5, 0.5, 1, true)
		view.scripts.OnMouseWheel(view, 1)
		Tick(1)
		expect(BF.Seamless.State.zoom > 1.3, "zoomed in")
		view.scripts.OnMouseUp(view, "RightButton")
		Tick(1)
		expect(BF.Seamless.State.zoom < 1.4, "back out")
	end,
}
