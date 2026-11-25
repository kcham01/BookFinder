-- The game's functions, asked the way WoW: Forever answers.
--
-- Forever runs on the modern client: many old global functions are gone there (GetItemCount, GetFactionInfoByID,
-- GetSkillLineInfo ...) and live in C_ namespaces instead. Every other file asks through BF.Game, which tries the
-- modern form first and the old global second, and never calls a function that isn't there.

local _, BF = ...

local Game = {}
BF.Game = Game

local function global(name)
	local fn = rawget(_G, name)
	return type(fn) == "function" and fn or nil
end

local function namespaced(space, name)
	local t = rawget(_G, space)
	local fn = type(t) == "table" and rawget(t, name)
	return type(fn) == "function" and fn or nil
end

--- How many of an item the player carries (bags; with the bank when `bank`).
function Game.ItemCount(item, bank)
	local fn = namespaced("C_Item", "GetItemCount") or global("GetItemCount")
	return fn and fn(item, bank and true or false) or 0
end

--- A faction's name and the player's standing with it (points from the bottom of Neutral), or nil.
function Game.Faction(factionID)
	local modern = namespaced("C_Reputation", "GetFactionDataByID")
	if modern then
		local d = modern(factionID)
		if type(d) ~= "table" or not d.name or d.name == "" then return nil end
		return d.name, d.currentStanding
	end
	local old = global("GetFactionInfoByID")
	if not old then return nil end
	local name, _, _, _, _, value = old(factionID)
	if not name then return nil end
	return name, value
end

--- A spell's name, or nil.
function Game.SpellName(spell)
	local modern = namespaced("C_Spell", "GetSpellName")
	if modern then return modern(spell) end
	local info = namespaced("C_Spell", "GetSpellInfo")
	if info then
		local d = info(spell)
		return type(d) == "table" and d.name or nil
	end
	local old = global("GetSpellInfo")
	return old and (old(spell)) or nil
end

--- Whether the player knows a spell.
function Game.SpellKnown(spell)
	local fn = namespaced("C_SpellBook", "IsSpellKnown") or global("IsPlayerSpell") or global("IsSpellKnown")
	return fn and fn(spell) and true or false
end

--- The skill lines the player has, as a list of { name, isHeader, rank, skillID (when the client gives it) }.
function Game.SkillLines()
	local lines = {}
	local count = namespaced("C_SkillInfo", "GetNumSkillLines")
	local line = namespaced("C_SkillInfo", "GetSkillLineInfo")
	if count and line then
		for i = 1, count() or 0 do
			local d = line(i)
			if type(d) == "table" then
				lines[#lines + 1] = { name = d.name, isHeader = d.isHeader, rank = d.rank, skillID = d.skillID }
			end
		end
		return lines
	end
	count, line = global("GetNumSkillLines"), global("GetSkillLineInfo")
	if not (count and line) then return lines end
	for i = 1, count() or 0 do
		local name, isHeader, _, rank = line(i)
		if name then lines[#lines + 1] = { name = name, isHeader = isHeader, rank = rank } end
	end
	return lines
end

--- A quest's chat link, or nil.
function Game.QuestLink(id)
	local fn = namespaced("C_QuestLog", "GetQuestLink") or global("GetQuestLink")
	local link = fn and fn(id)
	return link ~= "" and link or nil
end

--- The level range below the player's in which quests are still worth XP ("green"), as the game counts it.
function Game.GreenRange()
	local fn = namespaced("C_QuestLog", "GetTrivialRange")
	if fn then return fn() end
	fn = global("UnitQuestTrivialLevelRange")
	if fn then return fn("player") end
	fn = global("GetQuestGreenRange")
	if fn then return fn("player") end
	return nil
end

--- Money as coin icons ("1g 20s 5c" with the game's coin textures).
function Game.Coins(money)
	local fn = namespaced("C_CurrencyInfo", "GetCoinTextureString") or global("GetCoinTextureString")
	return fn and fn(money) or nil
end

--- A console variable's value as a string.
function Game.CVar(name)
	local fn = namespaced("C_CVar", "GetCVar") or global("GetCVar")
	return fn and fn(name) or nil
end

--- A console variable's value as a number (0 when unset).
function Game.CVarNumber(name)
	return tonumber(Game.CVar(name)) or 0
end

--- Sends a chat message (party, raid, say ...).
function Game.Chat(text, channel, target)
	local fn = namespaced("C_ChatInfo", "SendChatMessage") or global("SendChatMessage")
	if fn then fn(text, channel, nil, target) end
end

--- The quest difficulty colour of a level ({ r, g, b }), or nil.
function Game.LevelColor(level)
	local fn = global("GetQuestDifficultyColor")
	return fn and fn(level) or nil
end
