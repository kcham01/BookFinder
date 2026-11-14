-- Every quest setting, declared once (the settings panel is built from these). Pages are the Quests tab's pages.
-- Each setting matches one of Questie's (docs/study/questie.md, its defaults kept); the few Questie settings with no
-- counterpart here are listed at the bottom with why.

local _, BF = ...
local S = BF.Settings

-- Settings whose feature is not built yet: declared now (their defaults are Questie's), left out of the settings panel
-- until the code that reads them exists. Take a key off this list in the same change that builds its feature
-- (tools/test/test_panel.lua checks both ways).
local PENDING_PREFIXES = { "list.", "auto.", "announce.", "sounds.", "dbm." }
local PENDING = { ["party.objectives"] = true, ["quests.frameIcons"] = true, ["icons.clusterSpawns"] = true }

local function pending(key)
	if PENDING[key] then return true end
	for _, prefix in ipairs(PENDING_PREFIXES) do
		if key:sub(1, #prefix) == prefix then return true end
	end
	return false
end

local G -- the heading the next settings stand under in the panel (nil: none)

local function def(key, default, page, label, extra)
	extra = extra or {}
	extra.default, extra.page, extra.label, extra.group = default, page, label, G
	if pending(key) then extra.pending = true end
	S:Define(key, extra)
end

-- Map icons ---------------------------------------------------------------------------------------------------------
local P = "Quests/Map"
G = "Icons"
def("quests.map", true, P, "Quest icons on the map")
def("quests.minimap", true, P, "Quest icons on the minimap")
G = "Quests shown"
def("quests.available", true, P, "Quests you can pick up")
def("quests.turnins", true, P, "Where to hand in")
def("quests.objectives", true, P, "Objectives")
def("quests.itemStarts", true, P, "Quests started by an item")
def("quests.repeatable", true, P, "Repeatable quests")
def("quests.events", true, P, "Holiday quests")
def("quests.dungeon", true, P, "Dungeon quests")
def("quests.raid", true, P, "Raid quests")
def("quests.pvp", true, P, "PvP quests")
def("quests.aqWarEffort", false, P, "Ahn'Qiraj war effort quests")
G = "Low-level quests"
def("quests.lowLevel", "hide", P, "Low-level quests", {
	choices = { "hide", "all", "offset", "range" },
	choiceLabels = { hide = "Hide", all = "Show all", offset = "Levels below mine", range = "Level range" },
})
-- Each number counts only with its style: the panel greys it out otherwise.
local function styleIs(style) return function() return BF:Get("quests.lowLevel") == style end end
def("quests.lowLevelOffset", 7, P, "Levels below mine", { min = 1, max = 60, step = 1, enabledIf = styleIs("offset") })
def("quests.levelMin", 1, P, "From level", { min = 1, max = 60, step = 1, enabledIf = styleIs("range") })
def("quests.levelMax", 10, P, "To level", { min = 1, max = 60, step = 1, enabledIf = styleIs("range") })
G = "Hiding"
def("icons.hideUnexplored", false, P, "Hide in unexplored areas")
def("icons.hideUntracked", false, P, "Hide untracked quests")
def("icons.hideOnContinents", false, P, "Hide on continent maps")
G = "Colours and glow"
def("icons.colorsMap", false, P, "A colour per quest on the map")
def("icons.colorsMinimap", false, P, "A colour per quest on the minimap")
def("icons.glowMap", true, P, "Glow on the map")
def("icons.glowMinimap", true, P, "Glow on the minimap")
G = "Patrol paths"
def("paths.map", true, P, "Patrol paths on the map")
def("paths.minimap", true, P, "Patrol paths on the minimap")

-- Icon look ---------------------------------------------------------------------------------------------------------
P = "Quests/Look"
G = "Sizes"
def("icons.mapScale", 0.6, P, "Map icon size", { min = 0.2, max = 2, step = 0.05 })
def("icons.minimapScale", 0.7, P, "Minimap icon size", { min = 0.2, max = 2, step = 0.05 })
def("icons.townsfolkMapScale", 0.6, P, "Townsfolk size on the map", { min = 0.2, max = 2, step = 0.05 })
def("icons.townsfolkMinimapScale", 0.7, P, "Townsfolk size on the minimap", { min = 0.2, max = 2, step = 0.05 })
def("icons.scale.available", 1.2, P, "Quest givers", { min = 0.2, max = 3, step = 0.05 })
def("icons.scale.event", 1.35, P, "Events", { min = 0.2, max = 3, step = 0.05 })
def("icons.scale.slay", 1, P, "Slay", { min = 0.2, max = 3, step = 0.05 })
def("icons.scale.loot", 1, P, "Loot", { min = 0.2, max = 3, step = 0.05 })
def("icons.scale.object", 1, P, "Objects", { min = 0.2, max = 3, step = 0.05 })
G = "Objective icons"
def("icons.slay", "default", P, "Slay icon", { iconChoice = true })
def("icons.loot", "default", P, "Loot icon", { iconChoice = true })
def("icons.object", "default", P, "Object icon", { iconChoice = true })
def("icons.event", "default", P, "Event icon", { iconChoice = true })
def("icons.talk", "default", P, "Talk icon", { iconChoice = true })
def("icons.interact", "default", P, "Interact icon", { iconChoice = true })
G = "Fading"
def("icons.minimapFadeDistance", 20, P, "Minimap icons fade from (yards)", { min = 0, max = 100, step = 1 })
def("icons.fadeAlpha", 0.3, P, "Faded icon strength", { min = 0, max = 1, step = 0.05 })
def("icons.fadeOverPlayer", true, P, "Fade icons over your arrow")
def("icons.fadeOverPlayerDistance", 5, P, "Within (yards)", { min = 1, max = 30, step = 1 })
def("icons.fadeOverPlayerAlpha", 0.5, P, "Strength over your arrow", { min = 0, max = 1, step = 0.05 })
G = "Patrol paths"
def("paths.width", 3, P, "Path width", { min = 1, max = 10, step = 0.5 })
def("paths.opacity", 1, P, "Path strength", { min = 0.1, max = 1, step = 0.05 })
def("paths.color", { 1, 0.72, 0, 0.5 }, P, "Path colour", { color = true })
def("paths.hostileColor", { 1, 0.2, 0, 0.7 }, P, "Hostile path colour", { color = true })
def("paths.highlight", true, P, "Highlight a path on hover")
def("paths.highlightColor", { 0.93, 0.46, 0.13, 0.8 }, P, "Highlight colour", { color = true })
-- Coordinates belong to the map (the Map tab's Look page, where OpenMap keeps them): one place for them.
G = "Coordinates"
def("coords.map", true, "Map/Look", "Cursor coordinates on the map")
def("coords.minimap", false, "Map/Look", "Coordinates on the minimap")
def("coords.precision", 1, "Map/Look", "Coordinate decimals", { min = 0, max = 2, step = 1 })

-- Tooltips ----------------------------------------------------------------------------------------------------------
P = "Quests/Tooltips"
G = "Tooltips"
def("tooltips.enabled", true, P, "Quest lines in tooltips")
def("tooltips.npcQuests", true, P, "Quests on NPC tooltips")
def("tooltips.questLevel", true, P, "Quest levels")
def("tooltips.xpAtMaxLevel", false, P, "Quest XP at max level")
def("tooltips.nextInChain", true, P, "Next quest in the chain")
def("tooltips.breadcrumbs", false, P, "Breadcrumb quests")
def("tooltips.dropRates", true, P, "Drop rates")
G = "IDs"
def("tooltips.ids.quest", false, P, "Quest IDs")
def("tooltips.ids.npc", false, P, "NPC IDs")
def("tooltips.ids.object", false, P, "Object IDs")
def("tooltips.ids.item", false, P, "Item IDs")
def("tooltips.ids.spell", false, P, "Spell IDs")
G = "Quest windows"
def("quests.frameIcons", true, P, "Quest icons in quest and gossip windows")
G = "Nameplates and target"
def("nameplates.enabled", true, P, "Quest icons on nameplates")
def("nameplates.x", -17, P, "Nameplate icon left/right", { min = -200, max = 200, step = 1 })
def("nameplates.y", -7, P, "Nameplate icon up/down", { min = -200, max = 200, step = 1 })
def("nameplates.scale", 1, P, "Nameplate icon size", { min = 0.2, max = 4, step = 0.05 })
def("nameplates.target", true, P, "Quest icon on the target frame")
def("nameplates.targetX", -30, P, "Target icon left/right", { min = -200, max = 200, step = 1 })
def("nameplates.targetY", 25, P, "Target icon up/down", { min = -200, max = 200, step = 1 })
def("nameplates.targetScale", 1.7, P, "Target icon size", { min = 0.2, max = 4, step = 0.05 })

-- The quest list (in the map's Quests tab) ---------------------------------------------------------------------------
P = "Quests/List"
G = nil
def("list.autoTrack", true, P, "Track quests as you accept them")
def("list.showComplete", true, P, "Show finished quests")
def("list.questLevel", true, P, "Quest levels")
def("list.collapseComplete", false, P, "Fold finished quests")
def("list.focusButtons", true, P, "Focus buttons")
def("list.playButtons", true, P, "Voice-over buttons")
def("list.hideDoneObjectives", false, P, "Hide finished objectives")
def("list.hideCompletionText", false, P, "Hide the game's completion text")
def("list.followSuperTrack", false, P, "Follow the game's focused quest")
def("list.objectiveColors", "minimal", P, "Objective colours", {
	choices = { "white", "minimal", "whiteAndGreen", "whiteToGreen", "redToGreen" },
	choiceLabels = { white = "White", minimal = "Minimal", whiteAndGreen = "White, then green",
		whiteToGreen = "White to green", redToGreen = "Red to green" },
})
def("list.sort", "byZone", P, "Sort quests", {
	choices = { "byZone", "byProximity", "byLevel", "byLevelReversed", "byComplete", "none" },
	choiceLabels = { byZone = "By zone", byProximity = "By distance", byLevel = "By level",
		byLevelReversed = "By level, highest first", byComplete = "By progress", none = "As accepted" },
})
def("list.clickPin", "ctrlleft", P, "Map pin on", { choices = { "left", "shiftleft", "ctrlleft", "altleft", "right", "disabled" } })
def("list.clickOpenLog", "left", P, "Open the quest on", { choices = { "left", "shiftleft", "ctrlleft", "altleft", "right", "disabled" } })
def("list.clickUntrack", "shiftleft", P, "Untrack on", { choices = { "left", "shiftleft", "ctrlleft", "altleft", "right", "disabled" } })
def("list.padding", 4, P, "Space between quests", { min = 0, max = 12, step = 1 })
def("list.fontSizeZone", 12, P, "Zone text size", { min = 8, max = 20, step = 1 })
def("list.fontSizeQuest", 10, P, "Quest text size", { min = 8, max = 20, step = 1 })
def("list.fontSizeObjective", 10, P, "Objective text size", { min = 8, max = 20, step = 1 })

-- Automation and party ----------------------------------------------------------------------------------------------
P = "Quests/Automation"
G = "Automation"
def("auto.accept", false, P, "Accept quests")
def("auto.complete", false, P, "Hand in quests")
def("auto.modifier", "shift", P, "Hold to skip", { choices = { "shift", "ctrl", "alt" } })
def("auto.trivial", false, P, "Also low-level quests")
def("auto.repeatable", true, P, "Also repeatable quests")
def("auto.pvp", true, P, "Also PvP quests")
def("auto.rejectInBattleground", false, P, "Reject quests shared in battlegrounds")
def("auto.abandonBreadcrumb", false, P, "Abandon a breadcrumb once its quest is taken")
G = "Announcements"
def("announce.channel", "party", P, "Announce to", { choices = { "disabled", "party", "yell", "self" } })
def("announce.items", true, P, "Items that start quests")
def("announce.accepted", false, P, "Quests accepted")
def("announce.abandoned", false, P, "Quests abandoned")
def("announce.objectives", true, P, "Objectives done")
def("announce.completed", false, P, "Quests handed in")
def("announce.incompleteBreadcrumb", true, P, "Skipped breadcrumbs")
def("announce.quiet", false, P, "Hide quest announcements from others")
G = "Party"
def("party.objectives", true, P, "Party members' objectives")
G = "Sounds"
def("sounds.questComplete", false, P, "Sound: quest complete")
def("sounds.questCompleteChoice", "QuestComplete", P, "Quest complete sound", { soundChoice = true })
def("sounds.objectiveComplete", false, P, "Sound: objective done")
def("sounds.objectiveCompleteChoice", "ObjectiveComplete", P, "Objective done sound", { soundChoice = true })
def("sounds.objectiveProgress", false, P, "Sound: objective progress")
def("sounds.objectiveProgressChoice", "ObjectiveProgress", P, "Objective progress sound", { soundChoice = true })
def("sounds.channel", "Master", P, "Sound channel", { choices = { "Master", "SFX", "Music", "Ambience", "Dialog" } })
def("sounds.delay", 0.5, P, "Sound delay (seconds)", { min = 0, max = 3, step = 0.1 })

-- Advanced ----------------------------------------------------------------------------------------------------------
P = "Quests/Advanced"
G = "Icons"
def("icons.limitEnabled", false, P, "Limit how many icons are drawn")
def("icons.limit", 1500, P, "Most icons", { min = 100, max = 5000, step = 100 })
def("icons.availableLimit", 30, P, "Most places per quest giver", { min = 1, max = 100, step = 1 })
def("icons.clusterObjectives", 2, P, "Merge objective icons within (percent of map)", { min = 0, max = 10, step = 0.5 })
def("icons.clusterSpawns", 28, P, "Merge spawn icons within (yards)", { min = 0, max = 100, step = 1 })
G = "Deadly Boss Mods"
def("dbm.enabled", false, P, "Quest icons on Deadly Boss Mods' HUD")
def("dbm.alert", true, P, "HUD alert")
def("dbm.refresh", 0.03, P, "HUD refresh (seconds)", { min = 0.01, max = 0.5, step = 0.01 })
def("dbm.zoom", 100, P, "HUD zoom", { min = 10, max = 300, step = 5 })
def("dbm.radius", 3, P, "HUD icon radius", { min = 1, max = 10, step = 0.5 })
def("dbm.quest", true, P, "HUD: quest givers")
def("dbm.slay", false, P, "HUD: slay")
def("dbm.loot", false, P, "HUD: loot")
def("dbm.interact", true, P, "HUD: interact")

--[[ Questie settings with no counterpart here, and why:
	- iconTheme (Questie / pfQuest / Blizzard art): BookFinder ships no other addon's art; every icon is the game's own,
	  and each objective kind's icon can be chosen among the game's (icons.slay ... above).
	- mapShowHideEnabled (Questie's own map button): the map's Show dropdown holds every switch (docs/NOTES.md 1).
	- tracker window settings (lock, sizer, backdrop, border, hide/minimize in combat or instances, header, fonts'
	  faces): the quest list lives in the map's Quests tab, not in a window of its own.
	- showSoDRunes, Isle of Quel'Danas phase: not on WoW: Forever.
	- debug options and the profiler: development aids, not player settings.
	- loadCustomSounds: sound choices list the game's sounds, plus any registered with LibSharedMedia when another
	  addon provides it (sounds.*Choice).
]]
