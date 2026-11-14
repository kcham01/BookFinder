-- What party members share, shown: their objectives on the map and minimap (Quests > Automation > "Party members'
-- objectives"), and their progress on NPC tooltips, from BookFinder or Questie users alike (Comms/Questie.lua).
--
-- A party member's objective is drawn where the player has nothing of their own to draw for it (the player's own
-- unfinished objective of the same quest already shows there), only for quests they want shown (QuestieV1), and for
-- groups of five or fewer, as Questie does. Players heard nearby (yells) show on tooltips, marked "Nearby".

local _, BF = ...
local L = BF.L

local Party, Objectives, Log, Zones, Marks = BF.Party, BF.Objectives, BF.Log, BF.Zones, BF.Marks
local I = BF.I

local function shown(player, questID)
	return Party:NearbyShown(player) and Party:Visible(player, questID)
end

-- The player's own unfinished objectives of a quest, by index.
local function mine(questID)
	local own = {}
	if not Log:Has(questID) then return own end
	for _, rec in ipairs(Objectives:For(questID)) do
		if rec.index and not rec.finished then own[rec.index] = true end
	end
	return own
end

-- The map layer -------------------------------------------------------------------------------------------------------

Marks:RegisterLayer("party", function(add)
	if not BF:Get("party.objectives") or GetNumGroupMembers() > 5 then return end
	for questID, players in pairs(Party.quests) do
		local own = mine(questID)
		local data = Objectives:ForData(questID)
		for player, objectives in pairs(players) do
			if Party.group[player] and shown(player, questID) then
				for i, o in ipairs(objectives) do
					local rec = data[i]
					if rec and not o.finished and not own[i] then
						local placed = {} -- [map] = { {x, y}, ... }: one mark per small area per objective
						for _, s in ipairs(rec.sources or {}) do
							Zones:EachSpawn(Objectives:Spawns(s), function(map, x, y, inside)
								if inside then return end
								local list = placed[map] or {}
								placed[map] = list
								for _, p in ipairs(list) do
									if (p[1] - x) ^ 2 + (p[2] - y) ^ 2 < 0.015 ^ 2 then return end
								end
								list[#list + 1] = { x, y }
								add(map, x, y, "p:" .. questID .. ":" .. i .. ":" .. #list .. ":" .. map,
									{ role = "objective", quest = questID, objective = { index = i, name = rec.name, icon = rec.icon,
										text = ("%s: %d/%d"):format(rec.name or "", o.have, o.need) }, source = s, party = player })
							end)
						end
					end
				end
			end
		end
	end
end)

local rebuild = BF:Debounce(0.5, function() Marks:RebuildLayer("party") end)

-- Tooltips: each party member's progress on an NPC their objectives need ------------------------------------------

local function npcNeeded(npc, o)
	if not o.id then return false end
	if o.type == "m" then return o.id == npc end
	if o.type == "i" then
		local item = BF:Item(o.id)
		for _, n in ipairs(item and item[I.npcDrops] or {}) do if n == npc then return true end end
	end
	return false
end

BF.Tooltips:Register("npc", function(tip, npc)
	if not BF:Get("tooltips.enabled") then return end
	for questID, players in pairs(Party.quests) do
		local lines = {}
		for player, objectives in pairs(players) do
			if Party:NearbyShown(player) then
				for _, o in ipairs(objectives) do
					if not o.finished and npcNeeded(npc, o) then
						local who = Party.group[player] and player or (player .. " (" .. L["Nearby"] .. ")")
						lines[#lines + 1] = ("   %s: %d/%d"):format(who, o.have, o.need)
					end
				end
			end
		end
		if #lines > 0 then
			table.sort(lines)
			local q = Log:Get(questID)
			tip:AddLine(BF.Rules:ColoredTitle(questID, q and q.title, BF:Get("tooltips.questLevel")))
			for _, line in ipairs(lines) do tip:AddLine(line, 0.6, 0.8, 1) end
		end
	end
end)

BF:At("login", function()
	BF:Listen("BF_PARTY_CHANGED", rebuild)
	BF:Listen("BF_QUEST_LOG_CHANGED", rebuild)
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key == "party.objectives" then rebuild() end end)
end, 62)
