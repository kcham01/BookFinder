-- OpenMap shipped beside BookFinder: its switches in the Show dropdown, its settings on the panel, all through its own
-- options. A stand-in OpenMap: its saved settings, its API global, and its options registered with AceConfig.

local function standIn()
	World.addons.OpenMap = { Version = "v0.8.9" }
	OpenMapDB = { worldmap = { boats = true, zeppelins = true, flight = true, routes = false, icons = true, dungeonMaps = true,
		dungeonLevels = true, unexplored = "show", brightness = 1, mapButtons = true, minimapButton = true, tabRail = false,
		autoSwitch = true } }
	OpenMapCharDB = { worldmap = {} }
	OpenMapStandIn = { refreshed = 0, dungeonMapsSet = 0 }
	OpenMapAPI = { IsStitched = function() return false end }
	local db = OpenMapDB.worldmap
	local function get(info) return db[info[#info]] end
	local function set(info, v) db[info[#info]] = v OpenMapStandIn.refreshed = OpenMapStandIn.refreshed + 1 end
	local args = {
		boats = { type = "toggle", name = "Boats", get = get, set = set },
		zeppelins = { type = "toggle", name = "Zeppelins", get = get, set = set },
		flight = { type = "toggle", name = "Flight masters", get = get, set = set },
		routes = { type = "toggle", name = "Boat and zeppelin routes", get = get, set = set },
		icons = { type = "toggle", name = "Dungeons and raids", get = get, set = set },
		autoSwitch = { type = "toggle", name = "Load the zone in view", get = get, set = set },
		mapButtons = { type = "toggle", name = "OpenMap button", get = get, set = set },
		minimapButton = { type = "toggle", name = "Minimap button", get = get, set = set },
		gapMinimap = { type = "toggle", name = "Gaps", get = get, set = set, hidden = function() return true end },
		dungeonMaps = { type = "toggle", name = "Dungeon maps", get = get,
			set = function(_, v) db.dungeonMaps = v OpenMapStandIn.dungeonMapsSet = OpenMapStandIn.dungeonMapsSet + 1 end },
		unexplored = { type = "select", name = "Unexplored areas", get = get, set = set,
			values = { show = "Show", dim = "Darken", hide = "Hide" }, sorting = { "show", "dim", "hide" } },
		entranceClick = { type = "select", name = "Entrance", get = get, set = set, values = { map = "Its map", journal = "Journal" } },
		brightness = { type = "range", name = "Map brightness", min = 0.25, max = 1, step = 0.05, isPercent = true, get = get, set = set },
		darkenColor = { type = "color", name = "Darkening colour",
			get = function() local c = db.darkenColor if c then return c[1], c[2], c[3] end return 0.05, 0.06, 0.08 end,
			set = function(_, r, g, b) db.darkenColor = { r, g, b } end },
	}
	local registry = { GetOptionsTable = function(_, app) if app == "OpenMap" then return { type = "group", args = args } end end }
	LibStub = setmetatable({}, { __call = function(_, name) if name == "AceConfigRegistry-3.0" then return registry end end })
	SlashCmdList.OPENMAP = function(word) OpenMapStandIn.slash = word end
end

local function findItem(items, text)
	for _, i in ipairs(items) do if i.text == text then return i end end
end

return {
	before = standIn,

	["openmap: its map items are in the Show dropdown once, dungeons in their own section"] = function(BF)
		Login()
		local items = BF.ShowMenu:Items()
		local boats = findItem(items, "Boats")
		expect(boats, "Boats in the list")
		expect(boats.checked(), "ticked as OpenMap has it")
		boats.onClick(boats, false)
		equal(OpenMapDB.worldmap.boats, false, "OpenMap's own setting changed")
		expect(OpenMapStandIn.refreshed > 0, "through OpenMap's option (it redraws)")
		local count, section, dungeonsAt, iconsAt = 0, false, nil, nil
		for i, item in ipairs(items) do
			if item.text == "Boats" then count = count + 1 end
			if item.title then section = true end
			if item.title and item.text == "Dungeons" then dungeonsAt = i end
			if item.text == "Dungeons and raids" then iconsAt = i end
		end
		equal(count, 1, "Boats once")
		expect(dungeonsAt and iconsAt and iconsAt > dungeonsAt, "Dungeons and raids under the Dungeons heading")
		expect(findItem(items, "Entrances open Dungeon Journal"), "the journal switch, as OpenMap offers one")
		local maps = findItem(items, "Dungeon maps")
		maps.onClick(maps, false)
		equal(OpenMapStandIn.dungeonMapsSet, 1, "Dungeon maps through OpenMap's own setter")
		expect(section, "a section")
	end,

	["openmap: one switch for flight masters, OpenMap's drawn on the world map"] = function(BF)
		Login()
		local item = findItem(BF.ShowMenu:Items(), "Flight Master")
		expect(item, "one Flight Master item")
		equal(findItem(BF.ShowMenu:Items(), "Flight masters"), nil, "not OpenMap's as well")
		item.onClick(item, false)
		equal(OpenMapDB.worldmap.flight, false, "OpenMap's off too")
		equal(BF:Get("townsfolk.flightMaster"), false, "BookFinder's off")
		item.onClick(item, true)
		expect(BF.OpenMap:DrawsFlightMasters(), "OpenMap draws them")
	end,

	["openmap: the panel's OpenMap tab holds its settings, sliders with OpenMap's ranges"] = function(BF)
		Login()
		local def = BF.Settings:Definition("openmap.brightness")
		equal(def.min, 0.25, "OpenMap's least")
		equal(def.max, 1, "OpenMap's most")
		local placed = BF.Panel:PlacedKeys()
		expect(placed["openmap.brightness"], "brightness on the panel")
		expect(placed["openmap.unexplored"], "unexplored on the panel")
		expect(placed["openmap.darkenColor"], "darkening colour on the panel")
		expect(not placed["openmap.gapMinimap"], "a setting OpenMap hides isn't")
		expect(not placed["map.seamless"], "BookFinder's own map's switch steps aside")
		BF:Set("openmap.unexplored", "dim")
		equal(OpenMapDB.worldmap.unexplored, "dim", "a choice reaches OpenMap")
		BF:Set("openmap.darkenColor", { 1, 0, 0, 1 })
		equal(OpenMapDB.worldmap.darkenColor[1], 1, "a colour reaches OpenMap")
		BF:Set("openmap.tabRail", true)
		equal(OpenMapDB.worldmap.tabRail, true, "one its options lack is written straight")
		for _, page in ipairs(BF.Panel.tabs[1].pages) do
			BF.Panel:Open("openmap", page.key)
			expect(BookFinderPanel:IsShown(), page.key)
		end
	end,

	["openmap: its own map button goes once, BookFinder's panel being the menu"] = function(BF)
		Login()
		equal(OpenMapDB.worldmap.mapButtons, false, "OpenMap's map button off")
		BF:Set("openmap.mapButtons", true)
		Fire("PLAYER_LOGIN")
		equal(OpenMapDB.worldmap.mapButtons, true, "and left as the player sets it after")
	end,
}
