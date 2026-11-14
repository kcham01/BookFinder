local function rowsOf(level)
	local list = _G["BookFinderDropdown" .. level]
	local rows = {}
	for _, r in ipairs(list.rows) do if r.shown and r.item then rows[#rows + 1] = r end end
	return rows
end

local function find(rows, text)
	for _, r in ipairs(rows) do if r.item.text == text then return r end end
end

return {
	["show menu: covers the Show button, not the floor picker"] = function(BF)
		Login()
		expect(BookFinderMapShowButton, "cover made")
		expect(BookFinderMapShowButton.parent == WorldMapFrame.showButton, "on the Show button")
	end,

	["show menu: the game's entries first, then ours in Questie's order"] = function(BF)
		Login()
		BookFinderMapShowButton.scripts.OnClick(BookFinderMapShowButton)
		local rows = rowsOf(1)
		equal(rows[1].item.text, "Quest Objectives", "the game's entry first")
		expect(rows[2].item.divider, "then a divider")
		equal(rows[3].item.text, "Repair", "Questie's order starts with Repair")
		expect(find(rows, "Available Quest") and find(rows, "Trivial Quest") and find(rows, "Objective"), "quest items")
		expect(find(rows, "Library books"), "the books")
		expect(not find(rows, "Portal Trainer"), "no portal trainer for a warrior")
		expect(not find(rows, "Advanced Search") and not find(rows, "My Journey"), "no windows in it")
	end,

	["show menu: ticking changes the setting, the game's entry does the game's thing"] = function(BF)
		Login()
		BookFinderMapShowButton.scripts.OnClick(BookFinderMapShowButton)
		local rows = rowsOf(1)
		local repair = find(rows, "Repair")
		repair.scripts.OnClick(repair, "LeftButton")
		expect(BF:Get("townsfolk.repair"), "repair on")
		expect(BookFinderDropdown1:IsShown(), "menu still open")
		local game = find(rows, "Quest Objectives")
		game.scripts.OnClick(game, "LeftButton")
		equal(World.questObjectives, false, "the game's own toggle ran")
		local trivial = find(rows, "Trivial Quest")
		trivial.scripts.OnClick(trivial, "LeftButton")
		equal(BF:Get("quests.lowLevel"), "all", "trivial quests shown")
	end,

	["show menu: submenus for profession trainers and vendors"] = function(BF)
		Login()
		BookFinderMapShowButton.scripts.OnClick(BookFinderMapShowButton)
		local vendor = find(rowsOf(1), "Vendor")
		vendor.scripts.OnEnter(vendor)
		local sub = rowsOf(2)
		expect(find(sub, "Food") and find(sub, "Drink"), "vendor kinds")
		expect(not find(sub, "Poisons"), "no poisons for a warrior")
	end,
}
