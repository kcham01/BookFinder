-- Quest icons on nameplates and on the target frame: a mob a quest of the player's still needs carries that
-- objective's icon (the skull to slay, the bag to loot...) beside its nameplate and on the target frame.
--
-- Settings (Quests > Tooltips): nameplates.enabled, .x, .y, .scale; nameplates.target, .targetX, .targetY,
-- .targetScale (Questie's defaults). The icon is the same art as the map's (BF.Icons, the player's icon choices).
--
-- WoW: Forever: unit GUIDs can be secret in combat and in instances. Like Questie on Forever, the icons stand down in
-- combat and inside instances, and come back when the fight ends or the player steps outside.

local _, BF = ...

local Plates = {}
BF.Nameplates = Plates

local Needs, Icons, Tooltips = BF.Needs, BF.Icons, BF.Tooltips

local SIZE = 16

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

--- Icons stand down while any GUID could be secret.
local function standingDown()
	if InCombatLockdown() then return true end
	local inside = IsInInstance()
	return inside == true
end

--- The objective icon kind for a unit, or nil.
function Plates:KindFor(unit)
	if standingDown() then return nil end
	if not UnitExists(unit) then return nil end
	local guid = UnitGUID(unit)
	if not guid or secret(guid) then return nil end
	if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
	local kind, id = Tooltips:ParseGUID(guid)
	if kind ~= "npc" then return nil end
	if UnitIsDead and UnitIsDead(unit) and Needs:NpcIcon(id) ~= "loot" then return nil end
	local icon = Needs:NpcIcon(id)
	return icon and Icons:ObjectiveKind(icon) or nil
end

-- Nameplates ----------------------------------------------------------------------------------------------------

local icons = {} -- [nameplate frame] = texture (kept for the frame's life: the client reuses nameplate frames)
local units = {} -- [unit token] = nameplate frame

local function iconFor(plate)
	local t = icons[plate]
	if not t then
		t = plate:CreateTexture(nil, "OVERLAY")
		icons[plate] = t
	end
	return t
end

local function place(t, plate)
	local scale = BF:Get("nameplates.scale")
	t:ClearAllPoints()
	t:SetPoint("CENTER", plate, "LEFT", BF:Get("nameplates.x"), BF:Get("nameplates.y"))
	t:SetSize(SIZE * scale, SIZE * scale)
end

local function updatePlate(unit)
	local plate = units[unit]
	if not plate then return end
	local kind = BF:Get("nameplates.enabled") and Plates:KindFor(unit)
	local t = icons[plate]
	if not kind then
		if t then t:Hide() end
		return
	end
	t = iconFor(plate)
	Icons:Apply(t, kind)
	place(t, plate)
	t:Show()
end

local function added(_, unit)
	if type(unit) ~= "string" or secret(unit) then return end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if not plate then return end
	units[unit] = plate
	updatePlate(unit)
end

local function removed(_, unit)
	local plate = units[unit]
	if plate and icons[plate] then icons[plate]:Hide() end
	units[unit] = nil
end

function Plates:UpdateAll()
	for unit in pairs(units) do updatePlate(unit) end
	Plates:UpdateTarget()
end

-- The target frame ----------------------------------------------------------------------------------------------

local targetIcon

function Plates:UpdateTarget()
	local frame = TargetFrame
	if not frame then return end
	local kind = BF:Get("nameplates.target") and Plates:KindFor("target")
	if not kind then
		if targetIcon then targetIcon:Hide() end
		return
	end
	if not targetIcon then
		-- A frame of our own over the target frame, so the icon draws above its portrait ring.
		local holder = CreateFrame("Frame", nil, frame)
		holder:SetAllPoints(frame)
		holder:SetFrameLevel(frame:GetFrameLevel() + 5)
		targetIcon = holder:CreateTexture(nil, "OVERLAY")
	end
	Icons:Apply(targetIcon, kind)
	local scale = BF:Get("nameplates.targetScale")
	targetIcon:ClearAllPoints()
	targetIcon:SetPoint("CENTER", frame, "RIGHT", BF:Get("nameplates.targetX"), BF:Get("nameplates.targetY"))
	targetIcon:SetSize(SIZE * scale, SIZE * scale)
	targetIcon:Show()
end

-- When ----------------------------------------------------------------------------------------------------------

local soon = BF:Debounce(0.1, function() Plates:UpdateAll() end)

BF:At("login", function()
	if not C_NamePlate then return end
	BF:On("NAME_PLATE_UNIT_ADDED", added)
	BF:On("NAME_PLATE_UNIT_REMOVED", removed)
	BF:On("PLAYER_TARGET_CHANGED", function() Plates:UpdateTarget() end)
	-- A mob that dies may keep a loot icon or lose its slay icon.
	BF:On("UNIT_FLAGS", function(_, unit)
		if units[unit] then updatePlate(unit) end
		if unit == "target" then Plates:UpdateTarget() end
	end)
	BF:On("PLAYER_REGEN_DISABLED", function()
		-- Stand down at once: the GUIDs are about to be secret.
		for _, t in pairs(icons) do t:Hide() end
		if targetIcon then targetIcon:Hide() end
	end)
	BF:On("PLAYER_REGEN_ENABLED", soon)
	BF:On("PLAYER_ENTERING_WORLD", soon)
	BF:Listen("BF_NEEDS_CHANGED", soon)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key:find("^nameplates%.") or key:find("^icons%.") then soon() end
	end)
end, 70)
