-- The error catcher: errors kept with their stack, counted, reported as one text; BookFinder's said once in chat.

local function setup()
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	Login()
end

local function said(text)
	for _, line in ipairs(World.printed or {}) do if tostring(line):find(text, 1, true) then return true end end
	return false
end

return {
	["an error is kept, counted when it repeats, and handed on to the game's handler"] = function(BF)
		setup()
		local handler = geterrorhandler()
		handler("Interface\\AddOns\\BookFinder\\Books\\Books.lua:62: attempt to call a nil value")
		handler("Interface\\AddOns\\BookFinder\\Books\\Books.lua:62: attempt to call a nil value")
		local log = BookFinderDB.errorLog
		equal(#log, 1, "one entry")
		equal(log[1].count, 2, "counted twice")
		equal(#World.errors, 2, "handed on both times")
		wipe(World.errors)
		local report = BF.Errors:Report()
		expect(report:find("Books.lua:62", 1, true) and report:find("x2", 1, true), "in the report, with its count")
	end,

	["BookFinder's error is said in chat once; another addon's is kept quietly"] = function(BF)
		setup()
		geterrorhandler()("Interface\\AddOns\\Other\\Other.lua:1: oops")
		Tick(1)
		expect(not said("/bf errors"), "another addon's: no chat line")
		geterrorhandler()("Interface\\AddOns\\BookFinder\\Map\\Minimap.lua:3: oops")
		geterrorhandler()("Interface\\AddOns\\BookFinder\\Map\\Minimap.lua:4: again")
		Tick(1)
		local n = 0
		for _, line in ipairs(World.printed or {}) do if tostring(line):find("/bf errors", 1, true) then n = n + 1 end end
		equal(n, 1, "one chat line")
		equal(#BookFinderDB.errorLog, 3, "all kept")
		wipe(World.errors)
	end,

	["/bf errors opens the report, selected"] = function(BF)
		setup()
		geterrorhandler()("Interface\\AddOns\\BookFinder\\x.lua:1: y")
		wipe(World.errors)
		BF.Commands:Run("errors")
		expect(BookFinderErrors.shown, "the window")
		expect(BookFinderErrors.box.text:find("x.lua:1", 1, true), "the error in it")
	end,
}
