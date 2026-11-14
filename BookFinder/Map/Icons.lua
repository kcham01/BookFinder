-- Icons: every kind of mark drawn with the game's own art.
--
-- Each kind lists candidates, best first: an atlas (used only if this client has it: C_Texture.GetAtlasInfo) or a
-- texture file that has shipped with every client since the original game. A missing texture draws as a solid green
-- square, so a file is listed only when it is certain to exist. BF.Icons:Apply(texture, kind) draws a kind.

local _, BF = ...

local Icons = {}
BF.Icons = Icons

local QUEST = "Interface\\GossipFrame\\"
local TRACK = "Interface\\Minimap\\Tracking\\"
local RAID = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"

-- tint: vertex colour; grey: desaturated and dimmed (a low-level quest)
local kinds = {
	available = { { atlas = "QuestNormal" }, { file = QUEST .. "AvailableQuestIcon" } },
	availableTrivial = { { atlas = "QuestNormal", grey = true }, { file = QUEST .. "AvailableQuestIcon", grey = true } },
	availableRepeatable = { { atlas = "QuestDaily" }, { file = QUEST .. "DailyQuestIcon" },
		{ file = QUEST .. "AvailableQuestIcon", tint = { 0.35, 0.65, 1 } } },
	availableEvent = { { atlas = "QuestLegendary" }, { file = QUEST .. "AvailableLegendaryQuestIcon" },
		{ file = QUEST .. "AvailableQuestIcon", tint = { 1, 0.55, 0.15 } } },
	availablePvP = { { atlas = "QuestNormal", tint = { 1, 0.35, 0.3 } }, { file = QUEST .. "AvailableQuestIcon", tint = { 1, 0.35, 0.3 } } },
	complete = { { atlas = "QuestTurnin" }, { file = QUEST .. "ActiveQuestIcon" } },
	completeRepeatable = { { atlas = "QuestRepeatableTurnin" }, { file = QUEST .. "DailyActiveQuestIcon" },
		{ file = QUEST .. "ActiveQuestIcon", tint = { 0.35, 0.65, 1 } } },
	completeEvent = { { atlas = "QuestTurnin", tint = { 1, 0.6, 0.2 } }, { file = QUEST .. "ActiveQuestIcon", tint = { 1, 0.6, 0.2 } } },
	incomplete = { { file = QUEST .. "IncompleteQuestIcon" } },

	slay = { { file = RAID .. "8" } },                                  -- skull
	loot = { { file = "Interface\\GroupFrame\\UI-Group-MasterLooter" } }, -- the loot bag
	object = { { file = "Interface\\Cursor\\Interact" } },              -- the cogwheel hand
	event = { { file = RAID .. "1" } },                                 -- star
	talk = { { file = QUEST .. "GossipGossipIcon" } },                  -- speech bubble
	interact = { { file = "Interface\\Cursor\\Interact" } },

	-- Townsfolk: the minimap's own tracking icons.
	innkeeper = { { file = TRACK .. "Innkeeper" } },
	banker = { { file = TRACK .. "Banker" } },
	mailbox = { { file = TRACK .. "Mailbox" } },
	auctioneer = { { file = TRACK .. "Auctioneer" } },
	flightMaster = { { file = TRACK .. "FlightMaster" } },
	battlemaster = { { file = TRACK .. "BattleMaster" } },
	classTrainer = { { file = TRACK .. "Class" } },
	professionTrainer = { { file = TRACK .. "Profession" } },
	repair = { { file = TRACK .. "Repair" } },
	stableMaster = { { file = TRACK .. "StableMaster" } },
	vendor = { { file = QUEST .. "VendorGossipIcon" } },
	food = { { file = TRACK .. "Food" } },
	ammo = { { file = TRACK .. "Ammunition" } },
	poisons = { { file = TRACK .. "Poisons" } },
	reagents = { { file = TRACK .. "Reagents" } },
	trainer = { { file = QUEST .. "TrainerGossipIcon" } },
	spiritHealer = { { atlas = "poi-soulspiritghost" }, { file = "Interface\\Icons\\Spell_Holy_Resurrection" } },
	weaponMaster = { { file = TRACK .. "Class", tint = { 0.85, 0.85, 1 } } },
	barber = { { atlas = "Barbershop-32x32" }, { file = QUEST .. "GossipGossipIcon" } },
	portalTrainer = { { file = "Interface\\Icons\\Spell_Arcane_PortalStormwind" } },
	transmogrifier = { { atlas = "poi-transmogrifier" }, { file = QUEST .. "VendorGossipIcon" } },
	meetingStone = { { file = "Interface\\Icons\\Spell_Shadow_Teleport" } },
	moonwell = { { file = "Interface\\Icons\\Spell_Nature_StarFall" } },
	rare = { { atlas = "VignetteKillElite" }, { file = RAID .. "8", tint = { 1, 0.8, 0.3 } } },

	glow = { { atlas = "WhiteCircle-RaidBlips" }, { file = "Interface\\Minimap\\UI-Minimap-Background" } },
	waypoint = { { atlas = "Waypoint-MapPin-Tracked" }, { file = "Interface\\Minimap\\Ping\\ping5" } },
	book = { { file = "Interface\\Icons\\INV_Misc_Book_09" } },
	userPin = { { atlas = "Waypoint-MapPin-Untracked" }, { file = "Interface\\Minimap\\Ping\\ping5" } },
	friend = { { atlas = "socialqueuing-icon-group" }, { file = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon" } },
	guild = { { file = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon" } },
	groupMember = { { atlas = "WhiteCircle-RaidBlips" }, { file = "Interface\\Minimap\\PartyRaidBlips" } },
}
Icons.kinds = kinds

-- The choices a player can pick for an objective kind's icon (Quests > Look): every objective art above, by name.
Icons.objectiveChoices = {
	{ key = "default", label = "Default" },
	{ key = "slay", label = "Skull" },
	{ key = "event", label = "Star" },
	{ key = "loot", label = "Loot bag" },
	{ key = "object", label = "Cogwheel" },
	{ key = "talk", label = "Speech bubble" },
	{ key = "raid2", label = "Circle", file = RAID .. "2" },
	{ key = "raid3", label = "Diamond", file = RAID .. "3" },
	{ key = "raid4", label = "Triangle", file = RAID .. "4" },
	{ key = "raid5", label = "Moon", file = RAID .. "5" },
	{ key = "raid6", label = "Square", file = RAID .. "6" },
	{ key = "raid7", label = "Cross", file = RAID .. "7" },
}
for _, c in ipairs(Icons.objectiveChoices) do
	if c.file and not kinds[c.key] then kinds[c.key] = { { file = c.file } } end
end

local resolved = {}

local function hasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

--- The first candidate this client can draw.
function Icons:Resolve(kind)
	local r = resolved[kind]
	if r then return r end
	local list = kinds[kind] or kinds.available
	for _, c in ipairs(list) do
		if c.atlas then
			if hasAtlas(c.atlas) then r = c break end
		else
			r = c
			break
		end
	end
	resolved[kind] = r
	return r
end

--- An objective kind as the player chose it (Quests > Look), else its own.
function Icons:ObjectiveKind(kind)
	local choice = BF:Get("icons." .. kind)
	if choice and choice ~= "default" and kinds[choice] then return choice end
	return kind
end

--- Draws `kind` on a texture region (and resets anything a previous kind left on it).
function Icons:Apply(texture, kind)
	local c = Icons:Resolve(kind)
	if c.atlas then
		texture:SetAtlas(c.atlas)
	else
		texture:SetTexture(c.file)
		texture:SetTexCoord(0, 1, 0, 1)
	end
	if c.tint then texture:SetVertexColor(c.tint[1], c.tint[2], c.tint[3], 1) else texture:SetVertexColor(1, 1, 1, 1) end
	if texture.SetDesaturated then texture:SetDesaturated(c.grey == true) end
	texture:SetAlpha(c.grey and 0.7 or 1)
end

--- The texture string for text ("|T...|t"), for tooltips and lists.
function Icons:Inline(kind, size)
	local c = Icons:Resolve(kind)
	size = size or 14
	if c.atlas then return CreateAtlasMarkup and CreateAtlasMarkup(c.atlas, size, size) or "" end
	return ("|T%s:%d:%d|t"):format(c.file, size, size)
end
