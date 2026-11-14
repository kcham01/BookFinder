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
local QUESTIE = "Interface\\AddOns\\BookFinder\\Media\\Questie\\" -- Questie's icon files (Media/Questie/README.md)

-- The look the owner asked for: Questie's icons, the way Questie uses them (the bag on what to loot, the "?" where a
-- quest is handed in...). Questie's three themes are kept: Questie's (default), pfQuest's monochrome objective icons,
-- and Blizzard's own (Quests > Look, icons.theme).
local kinds = {
	available = { { file = QUESTIE .. "available" } },
	availableTrivial = { { file = QUESTIE .. "available_gray" } },
	availableRepeatable = { { file = QUESTIE .. "repeatable" } },
	availableEvent = { { file = QUESTIE .. "eventquest" } },
	availablePvP = { { file = QUESTIE .. "pvpquest" } },
	availableMobDrop = { { file = QUESTIE .. "available_mobdrop.png" } },
	availableObject = { { file = QUESTIE .. "available_object.png" } },
	complete = { { file = QUESTIE .. "complete" } },
	completeRepeatable = { { file = QUESTIE .. "repeatable_complete" } },
	completeEvent = { { file = QUESTIE .. "eventquest_complete" } },
	completePvP = { { file = QUESTIE .. "pvpquest_complete" } },
	incomplete = { { file = QUESTIE .. "incomplete" } },

	slay = { { file = QUESTIE .. "slay" } },
	loot = { { file = QUESTIE .. "loot" } },
	object = { { file = QUESTIE .. "object" } },
	event = { { file = QUESTIE .. "event" } },
	talk = { { file = QUESTIE .. "chatbubblegossipicon" } },
	interact = { { file = QUESTIE .. "interact" } },
	chest = { { file = QUESTIE .. "chest" } },
	reputation = { { file = QUESTIE .. "reputation" } },
	nextQuest = { { file = QUESTIE .. "nextquest" } },
	breadcrumb = { { file = QUESTIE .. "breadcrumb.png" } },

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
	spiritHealer = { { file = "Interface\\RaidFrame\\Raid-Icon-Rez" } },
	weaponMaster = { { file = QUESTIE .. "weaponmaster" } },
	barber = { { file = QUESTIE .. "barbershop.png" } },
	portalTrainer = { { file = "Interface\\Minimap\\Vehicle-AllianceMagePortal" } },
	transmogrifier = { { file = TRACK .. "Transmogrifier" } },
	meetingStone = { { file = QUESTIE .. "mstone" } },
	moonwell = { { file = "Interface\\Icons\\INV_Fabric_Moonrag_01" } },
	rare = { { atlas = "VignetteKillElite" }, { file = RAID .. "8", tint = { 1, 0.8, 0.3 } } },

	glow = { { file = QUESTIE .. "glow" } },
	waypoint = { { atlas = "Waypoint-MapPin-Tracked" }, { file = "Interface\\Minimap\\Ping\\ping5" } },
	book = { { file = "Interface\\Icons\\INV_Misc_Book_09" } },
}
Icons.kinds = kinds

-- The other two themes replace some kinds (Questie's own themes: pfQuest's monochrome objectives; Blizzard's art).
local themes = {
	pfquest = {
		slay = { { file = QUESTIE .. "slay_mono.tga" } },
		loot = { { file = QUESTIE .. "loot_mono.tga" } },
		object = { { file = QUESTIE .. "object_mono.tga" } },
		interact = { { file = QUESTIE .. "object_mono.tga" } },
		event = { { file = QUESTIE .. "node.tga" } },
	},
	blizzard = {
		available = { { file = QUEST .. "AvailableQuestIcon" } },
		availableTrivial = { { file = QUEST .. "AvailableQuestIcon", grey = true } },
		availableRepeatable = { { file = QUEST .. "DailyQuestIcon" } },
		complete = { { file = QUEST .. "ActiveQuestIcon" } },
		completeRepeatable = { { file = QUEST .. "DailyActiveQuestIcon" } },
		slay = { { file = RAID .. "8" } },
		loot = { { file = "Interface\\GroupFrame\\UI-Group-MasterLooter" } },
		object = { { file = "Interface\\Cursor\\Interact" } },
		interact = { { file = "Interface\\Cursor\\Interact" } },
		event = { { file = RAID .. "1" } },
		talk = { { file = QUEST .. "GossipGossipIcon" } },
	},
}
Icons.themes = themes

-- The choices a player can pick for an objective kind's icon (Quests > Look): every objective art above, by name.
Icons.objectiveChoices = {
	{ key = "default", label = "Default" },
	{ key = "slay", label = "Slay" },
	{ key = "loot", label = "Loot" },
	{ key = "object", label = "Object" },
	{ key = "event", label = "Event" },
	{ key = "talk", label = "Talk" },
	{ key = "interact", label = "Interact" },
	{ key = "chest", label = "Chest" },
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
	local theme = BF.Settings:Definition("icons.theme") and BF:Get("icons.theme") or "questie"
	local key = theme .. ":" .. kind
	local r = resolved[key]
	if r then return r end
	local list = (themes[theme] and themes[theme][kind]) or kinds[kind] or kinds.available
	for _, c in ipairs(list) do
		if c.atlas then
			if hasAtlas(c.atlas) then r = c break end
		else
			r = c
			break
		end
	end
	resolved[key] = r
	return r
end

--- An objective kind as the player chose it (Quests > Look), else its own.
function Icons:ObjectiveKind(kind)
	local choice = BF:Get("icons." .. kind)
	if choice and choice ~= "default" and kinds[choice] then return choice end
	return kind
end

--- Draws `kind` on a texture region (and resets anything a previous kind left on it).
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- Spell and item icons are square: cut round (the game's portrait mask) so they sit with the round markers.
local function roundOff(texture, on)
	if not texture.AddMaskTexture then return end
	if on then
		if not texture.bfMask then
			local parent = texture:GetParent()
			if not (parent and parent.CreateMaskTexture) then return end
			texture.bfMask = parent:CreateMaskTexture()
			texture.bfMask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			texture.bfMask:SetAllPoints(texture)
		end
		if not texture.bfMasked then texture:AddMaskTexture(texture.bfMask) texture.bfMasked = true end
	elseif texture.bfMasked then
		texture:RemoveMaskTexture(texture.bfMask)
		texture.bfMasked = nil
	end
end

function Icons:Apply(texture, kind)
	local c = Icons:Resolve(kind)
	if c.atlas then
		texture:SetAtlas(c.atlas)
	else
		texture:SetTexture(c.file)
		texture:SetTexCoord(0, 1, 0, 1)
	end
	local square = c.file and c.file:find("^Interface\\Icons\\") ~= nil
	roundOff(texture, square)
	if square then texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
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
