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
local DOT = "Interface\\COMMON\\Indicator-"
local kinds = {
	-- Quest givers and turn-ins: the plain gold marks of the game's quest windows (no badge round them).
	available = { { file = QUEST .. "AvailableQuestIcon" } },
	availableTrivial = { { file = QUEST .. "AvailableQuestIcon", grey = true } },
	availableRepeatable = { { file = QUEST .. "DailyQuestIcon" } },
	availableEvent = { { file = QUEST .. "AvailableQuestIcon", tint = { 1, 0.55, 0.15 } } },
	availablePvP = { { file = QUEST .. "AvailableQuestIcon", tint = { 1, 0.35, 0.3 } } },
	complete = { { file = QUEST .. "ActiveQuestIcon" } },
	completeRepeatable = { { file = QUEST .. "DailyActiveQuestIcon" } },
	completeEvent = { { file = QUEST .. "ActiveQuestIcon", tint = { 1, 0.6, 0.2 } } },
	incomplete = { { file = QUEST .. "IncompleteQuestIcon" } },

	-- Objectives: small round markers, the game's own indicator lights, one colour per kind.
	slay = { { file = DOT .. "Red" } },
	loot = { { file = DOT .. "Yellow" } },
	object = { { file = DOT .. "Green" } },
	event = { { file = DOT .. "Gray" } },
	talk = { { file = DOT .. "Yellow" } },
	interact = { { file = DOT .. "Green" } },

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
}
Icons.kinds = kinds

-- The choices a player can pick for an objective kind's icon (Quests > Look): every objective art above, by name.
Icons.objectiveChoices = {
	{ key = "default", label = "Default" },
	{ key = "dotRed", label = "Red marker", file = DOT .. "Red" },
	{ key = "dotYellow", label = "Yellow marker", file = DOT .. "Yellow" },
	{ key = "dotGreen", label = "Green marker", file = DOT .. "Green" },
	{ key = "dotGray", label = "Grey marker", file = DOT .. "Gray" },
	{ key = "skull", label = "Skull", file = RAID .. "8" },
	{ key = "star", label = "Star", file = RAID .. "1" },
	{ key = "diamond", label = "Diamond", file = RAID .. "3" },
	{ key = "triangle", label = "Triangle", file = RAID .. "4" },
	{ key = "lootBag", label = "Loot bag", file = "Interface\\GroupFrame\\UI-Group-MasterLooter" },
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
