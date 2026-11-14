-- Quest marks on the minimap.
--
-- Pins are placed by world position relative to the player, in yards. The minimap shows a circle (or square) whose
-- size in yards depends on its zoom and on being indoors or out (the game's own table, below); when the minimap
-- rotates, positions turn with the player's facing. Every pin of the player's continent is indexed in a grid of
-- world cells once (when marks change or the continent does), so each update looks only at the cells nearby.

local _, BF = ...

local MinimapPins = {}
BF.MinimapPins = MinimapPins

local Marks, Look, Icons, Zones = BF.Marks, BF.Look, BF.Icons, BF.Zones
local sqrt, sin, cos, floor, abs = math.sqrt, math.sin, math.cos, math.floor, math.abs

-- The minimap's width in yards at each zoom level (0 = widest), outdoors and indoors.
local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }
local BASE_SIZE = 24
local CELL = 200 -- yards per index cell

-- Indoors is told by which zoom setting the minimap follows: the game keeps one for each.
local function minimapYards()
	local zoom = Minimap:GetZoom()
	local indoors = GetCVar("minimapZoom") + 0 ~= zoom and GetCVar("minimapInsideZoom") + 0 == zoom
	return (indoors and INDOOR or OUTDOOR)[zoom] or OUTDOOR[0]
end

local function isSquare()
	return GetMinimapShape and GetMinimapShape() == "SQUARE"
end

-- The index ---------------------------------------------------------------------------------------------------

local index = { instance = nil, cells = {}, version = -1 }

local function cellKey(cx, cy) return cx * 100000 + cy end

local function rebuildIndex(instance)
	index.instance, index.version = instance, Marks.version
	local cells = {}
	index.cells = cells
	for map in pairs(Marks.byMap) do
		for _, pin in ipairs(Marks:On(map)) do
			local inst, wx, wy = Zones:ToWorld(map, pin.x, pin.y)
			if inst == instance then
				local key = cellKey(floor(wx / CELL), floor(wy / CELL))
				local list = cells[key]
				if not list then
					list = {}
					cells[key] = list
				end
				list[#list + 1] = { pin = pin, wx = wx, wy = wy }
			end
		end
	end
end

-- Pin frames --------------------------------------------------------------------------------------------------

local pool, active = {}, {}

local function acquire()
	local f = table.remove(pool)
	if not f then
		f = CreateFrame("Frame", nil, Minimap)
		f:SetFrameStrata("MEDIUM")
		f.Glow = f:CreateTexture(nil, "BACKGROUND")
		f.Glow:SetPoint("CENTER")
		f.Icon = f:CreateTexture(nil, "ARTWORK")
		f.Icon:SetAllPoints()
		f:EnableMouse(true)
		f:SetScript("OnEnter", function(self)
			local pins = {}
			for _, other in ipairs(active) do
				if other ~= self and other:IsShown() and other:IsMouseOver() then pins[#pins + 1] = other.pin end
			end
			table.insert(pins, 1, self.pin)
			BF.PinTooltip:Show(self, pins, true)
		end)
		f:SetScript("OnLeave", function() BF.PinTooltip:Hide() end)
		f:SetScript("OnMouseUp", function(self, button)
			BF.PinTooltip.minimap = true
			BF.PinTooltip:Click(self.pin, button, nil, self)
		end)
	end
	f:Show()
	active[#active + 1] = f
	return f
end

local function releaseAll()
	for i = #active, 1, -1 do
		local f = active[i]
		f:Hide()
		f.pin = nil
		active[i] = nil
		pool[#pool + 1] = f
	end
end

local function style(f, pin)
	if f.styled == pin then return end
	f.styled = pin
	local kind, scaleKey = Look:Kind(pin)
	Icons:Apply(f.Icon, kind)
	local size = scaleKey == "townsfolk" and BASE_SIZE * BF:Get("icons.townsfolkMinimapScale")
		or BASE_SIZE * BF:Get("icons.minimapScale") * BF:Get("icons.scale." .. scaleKey)
	f:SetSize(size, size)
	local c = BF:Get("icons.glowMinimap") and Look:Glow(pin, true)
	if c then
		Icons:Apply(f.Glow, "glow")
		f.Glow:SetVertexColor(c[1], c[2], c[3], 1)
		f.Glow:SetSize(size * 1.4, size * 1.4)
		f.Glow:Show()
	else
		f.Glow:Hide()
	end
end

-- Placing -------------------------------------------------------------------------------------------------------

-- Layers drawn after the pins each update: fn(view), view nil when nothing is drawn (MinimapPins:AfterUpdate).
local after = {}
MinimapPins.view = {}

function MinimapPins:AfterUpdate(fn)
	after[#after + 1] = fn
end

--- A world offset from the player (yards north and west) as minimap pixels right and up, and whether it is inside.
function MinimapPins:Place(view, north, west)
	local right, up = -west, north
	if view.rotate then right, up = right * view.cs + up * view.sn, -right * view.sn + up * view.cs end
	local inside
	if view.square then inside = abs(right) <= view.radius and abs(up) <= view.radius
	else inside = right * right + up * up <= view.radius * view.radius end
	return right * view.pixelsPerYard, up * view.pixelsPerYard, inside
end

local function draw()
	if not BF:Get("quests.minimap") or not Minimap:IsVisible() then
		releaseAll()
		return false
	end
	local instance, px, py = Zones:PlayerWorld()
	if not instance then
		releaseAll()
		return false
	end
	if index.instance ~= instance or index.version ~= Marks.version then rebuildIndex(instance) end

	local yards = minimapYards()
	local radius = yards / 2
	local w, h = Minimap:GetWidth(), Minimap:GetHeight()
	local pixelsPerYard = w / yards
	local rotate = GetCVar("rotateMinimap") == "1"
	local facing = rotate and (GetPlayerFacing() or 0) or 0
	local cs, sn = cos(facing), sin(facing)
	local square = isSquare()
	local fadeFrom = BF:Get("icons.minimapFadeDistance")
	local fadeAlpha = BF:Get("icons.fadeAlpha")
	local overPlayer = BF:Get("icons.fadeOverPlayer")
	local overDistance = BF:Get("icons.fadeOverPlayerDistance")
	local overAlpha = BF:Get("icons.fadeOverPlayerAlpha")

	releaseAll()
	-- The same geometry for other layers drawn on the minimap (patrol paths): MinimapPins.view.
	local view = MinimapPins.view
	view.instance, view.px, view.py, view.radius, view.pixelsPerYard = instance, px, py, radius, pixelsPerYard
	view.rotate, view.cs, view.sn, view.square = rotate, cs, sn, square
	local reach = radius
	local c0x, c1x = floor((px - reach) / CELL), floor((px + reach) / CELL)
	local c0y, c1y = floor((py - reach) / CELL), floor((py + reach) / CELL)
	for cx = c0x, c1x do
		for cy = c0y, c1y do
			local list = index.cells[cellKey(cx, cy)]
			if list then
				for _, e in ipairs(list) do
					-- Offsets in yards: north is world +x, west is world +y. On screen: right = east, up = north.
					local north, west = e.wx - px, e.wy - py
					local dist = sqrt(north * north + west * west)
					local right, up = -west, north -- east, north
					if rotate then
						-- The minimap turns so the way the player faces is up: turn the offset clockwise by the
						-- facing (which counts counter-clockwise from north).
						right, up = right * cs + up * sn, -right * sn + up * cs
					end
					local inside
					if square then inside = abs(right) <= radius and abs(up) <= radius else inside = dist <= radius end
					if inside then
						local f = acquire()
						f.pin = e.pin
						style(f, e.pin)
						f:ClearAllPoints()
						f:SetPoint("CENTER", Minimap, "CENTER", right * pixelsPerYard, up * pixelsPerYard)
						local alpha = 1
						if fadeFrom > 0 and dist > fadeFrom then
							alpha = 1 - (1 - fadeAlpha) * math.min(1, (dist - fadeFrom) / math.max(1, radius - fadeFrom))
						end
						if overPlayer and dist < overDistance then alpha = math.min(alpha, overAlpha) end
						f:SetAlpha(alpha)
					end
				end
			end
		end
	end
	return true
end

local function update()
	local drawn = draw()
	for _, fn in ipairs(after) do BF.safecall(fn, drawn and MinimapPins.view or nil) end
end
MinimapPins.Update = update

-- When to update: often while the player moves or turns, rarely when still.
local driver = CreateFrame("Frame")
local elapsedSince, lastX, lastY, lastFacing, lastZoom = 0, nil, nil, nil, nil
driver:SetScript("OnUpdate", function(_, elapsed)
	elapsedSince = elapsedSince + elapsed
	if elapsedSince < 0.05 then return end
	local _, x, y = Zones:PlayerWorld()
	local facing = GetPlayerFacing() or 0
	local zoom = Minimap:GetZoom()
	local moved = x ~= lastX or y ~= lastY or zoom ~= lastZoom or (GetCVar("rotateMinimap") == "1" and facing ~= lastFacing)
	if moved or elapsedSince > 1 or index.version ~= Marks.version then
		elapsedSince = 0
		lastX, lastY, lastFacing, lastZoom = x, y, facing, zoom
		update()
	end
end)
driver:Hide()

BF:At("world", function()
	driver:Show()
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key:find("^icons%.") or key == "quests.minimap" then
			for _, f in ipairs(active) do f.styled = nil end
			for _, f in ipairs(pool) do f.styled = nil end
			update()
		end
	end)
end)
