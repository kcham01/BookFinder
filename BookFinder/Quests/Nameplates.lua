-- A quest marker on the nameplate (and the target frame) of any creature the player's quests still need: the
-- objective's own marker (to kill, to loot), placed and sized by the Tooltips page's settings. Off in instances on
-- WoW: Forever (unit identities can be secret there), as Questie does.

local _, BF = ...

local Plates = {}
BF.Nameplates = Plates

local Needs = BF.Needs
local markers = {} -- [nameplate frame] = marker

local function kindOf(entry)
	local icon = entry.objective and entry.objective.icon or "slay"
	if entry.via == "drop" then icon = "loot" end
	return BF.Icons:ObjectiveKind(icon)
end

local function markerFor(parent)
	local m = markers[parent]
	if not m then
		m = CreateFrame("Frame", nil, parent)
		m:SetSize(16, 16)
		m:SetFrameStrata("HIGH")
		m.icon = m:CreateTexture(nil, "OVERLAY")
		m.icon:SetAllPoints()
		markers[parent] = m
	end
	return m
end

-- "complete" when the NPC takes a finished quest, "available" when it offers one, else nil.
local function giverKind(npc)
	local n = BF:Npc(npc)
	if not n then return nil end
	for _, q in ipairs(n[BF.N.questEnds] or {}) do
		if BF.Log:Has(q) and BF.Log:IsComplete(q) then return "complete" end
	end
	for _, q in ipairs(n[BF.N.questStarts] or {}) do
		if BF.Rules:IsShown(q) then return BF.Rules:IsTrivial(q) and "availableTrivial" or "available" end
	end
end

local function npcOf(unit)
	if not UnitExists(unit) then return nil end
	local guid = UnitGUID(unit)
	return Needs:NpcFromGUID(guid)
end

local function blocked()
	local inInstance = IsInInstance()
	return inInstance
end

local function updatePlate(unit)
	local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
	if not plate then return end
	local m = markers[plate]
	local npc = npcOf(unit)
	local entry = BF:Get("nameplates.enabled") and not blocked() and Needs:OpenFor(npc or 0)
	local giver = not entry and BF:Get("nameplates.enabled") and not blocked() and npc and giverKind(npc)
	if not entry and not giver then
		if m then m:Hide() end
		return
	end
	m = markerFor(plate)
	local scale = BF:Get("nameplates.scale")
	m:ClearAllPoints()
	if giver then
		-- A quest to pick up ("!") or hand in ("?"): over the name, as Questie shows it.
		BF.Icons:Apply(m.icon, giver)
		m:SetSize(20 * scale, 20 * scale)
		m:SetPoint("BOTTOM", plate, "TOP", 0, 2)
	else
		BF.Icons:Apply(m.icon, kindOf(entry))
		m:SetSize(16 * scale, 16 * scale)
		m:SetPoint("LEFT", plate, "LEFT", BF:Get("nameplates.x"), BF:Get("nameplates.y"))
	end
	m:Show()
end

local function hidePlate(unit)
	local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
	if plate and markers[plate] then markers[plate]:Hide() end
end

local function updateAll()
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit then updatePlate(unit) end
	end
end

-- The target frame.
local target
local function updateTarget()
	if not TargetFrame then return end
	if not target then
		target = CreateFrame("Frame", nil, TargetFrame)
		target:SetFrameStrata("HIGH")
		target.icon = target:CreateTexture(nil, "OVERLAY")
		target.icon:SetAllPoints()
	end
	local entry = BF:Get("nameplates.target") and not blocked() and Needs:OpenFor(npcOf("target") or 0)
	if not entry then target:Hide() return end
	BF.Icons:Apply(target.icon, kindOf(entry))
	local scale = BF:Get("nameplates.targetScale")
	target:SetSize(16 * scale, 16 * scale)
	target:ClearAllPoints()
	target:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", BF:Get("nameplates.targetX"), BF:Get("nameplates.targetY"))
	target:Show()
end

BF:At("login", function()
	BF:On("NAME_PLATE_UNIT_ADDED", function(_, unit) updatePlate(unit) end)
	BF:On("NAME_PLATE_UNIT_REMOVED", function(_, unit) hidePlate(unit) end)
	BF:On("PLAYER_TARGET_CHANGED", updateTarget)
	BF:Listen("BF_NEEDS_CHANGED", function() updateAll() updateTarget() end)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key:find("^nameplates%.") or key:find("^icons%.") then updateAll() updateTarget() end
	end)
	BF:On("PLAYER_ENTERING_WORLD", function() updateAll() updateTarget() end)
end, 64)
