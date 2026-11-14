-- Slash commands: /bookfinder and /bf open the panel; more words do more (BF.Commands:Add).

local _, BF = ...
local L = BF.L

local Commands = { list = {} }
BF.Commands = Commands

--- Adds "/bf <word> ...": run(rest of the line), help = one line for /bf help.
function Commands:Add(word, help, run)
	Commands.list[word] = { help = help, run = run }
end

Commands:Add("help", "this list", function()
	BF:Print(L["/bf opens the panel. Also:"])
	local words = {}
	for word in pairs(Commands.list) do words[#words + 1] = word end
	table.sort(words)
	for _, word in ipairs(words) do BF:Print("  /bf %s - %s", word, L[Commands.list[word].help]) end
end)
Commands:Add("journey", "My Journey", function() BF.Panel:Open("journey", "myJourney") end)
Commands:Add("search", "Advanced Search", function() BF.Panel:Open("journey", "search") end)
Commands:Add("books", "the books' settings", function() BF.Panel:Open("books") end)
Commands:Add("route", "the books' route on or off", function() BF.BookRoute:Toggle() end)
Commands:Add("tomap", "<npc|object> <name or ID> shows it on the map (none: your target); tomap reset", function(rest)
	local kind, what = rest:match("^(%S*)%s*(.-)$")
	if kind == "reset" then BF.Search:ClearMap() return end
	if kind ~= "npc" and kind ~= "object" then what, kind = rest, "npc" end
	BF.Search:ToMap(kind, what)
end)
Commands:Add("guide", "move the arrow and the compass", function() BF.Guide:ToggleMoving() end)

local function run(line)
	local word, rest = (line or ""):match("^%s*(%S*)%s*(.-)%s*$")
	word = word:lower()
	if word == "" then BF.Panel:Toggle() return end
	local c = Commands.list[word]
	if c then c.run(rest) else Commands.list.help.run() end
end

SLASH_BOOKFINDER1, SLASH_BOOKFINDER2 = "/bookfinder", "/bf"
SlashCmdList.BOOKFINDER = run
