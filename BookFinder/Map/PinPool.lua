-- Pins for the game's map canvas, made in Lua.
--
-- WoW: Forever's canvas asserts on BookFinder's pins when they come from XML templates with their own mouse scripts
-- (seen in the owner's test of the other build: Blizzard_MapCanvas, a new pin must not have OnEnter/OnLeave). So each
-- kind of pin has its own pool, kept in the map's pinPools under the kind's name: the canvas then only asks the pool
-- for pins (Acquire, Release, ReleaseAll, EnumerateActive) and never looks a template up.
--
-- The pin itself takes no mouse, so the canvas never wires or checks it. A child frame over the pin (pin.Hit) takes
-- the mouse with its own scripts and calls the pin's OnMouseEnter, OnMouseLeave and OnMouseUp(button).

local _, BF = ...

local PinPool = {}
BF.PinPool = PinPool

local function noop() end

local function makeHit(pin)
	local hit = CreateFrame("Frame", nil, pin)
	hit:SetAllPoints()
	hit:EnableMouse(true)
	hit:SetScript("OnEnter", function() if pin.OnMouseEnter then pin:OnMouseEnter() end end)
	hit:SetScript("OnLeave", function() if pin.OnMouseLeave then pin:OnMouseLeave() end end)
	hit:SetScript("OnMouseUp", function(_, button) if pin.OnMouseUp then pin:OnMouseUp(button) end end)
	-- Right-click goes through to the map (zoom out), as on the game's own pins; not allowed in combat.
	if hit.SetPassThroughButtons and not InCombatLockdown() then pcall(hit.SetPassThroughButtons, hit, "RightButton") end
	pin.Hit = hit
	return hit
end

--- Registers the pool `name` on `map`. Its pins get `mixin`, are laid out by build(pin) (textures and text), and
--- take the mouse through pin.Hit unless `noMouse`.
function PinPool:Register(map, name, mixin, build, noMouse)
	map.pinPools = map.pinPools or {}
	if map.pinPools[name] then return map.pinPools[name] end
	local canvas = map.GetCanvas and map:GetCanvas() or map
	local pool = { active = {}, free = {}, numActive = 0 }

	function pool:Acquire()
		local pin = table.remove(self.free)
		local new = false
		if not pin then
			pin = CreateFrame("Frame", nil, canvas)
			pin:SetSize(1, 1)
			Mixin(pin, mixin)
			pin:EnableMouse(false)
			-- The canvas sets this on every pin it acquires; it errors in combat, and these pins take no mouse.
			pin.SetPassThroughButtons = noop
			build(pin)
			if not noMouse then makeHit(pin) end
			if pin.OnLoad then pin:OnLoad() end
			new = true
		end
		pin.pinTemplate, pin.owningMap = name, map
		self.active[pin] = true
		self.numActive = self.numActive + 1
		pin:Show()
		return pin, new
	end

	function pool:Release(pin)
		if not self.active[pin] then return false end
		self.active[pin] = nil
		self.numActive = self.numActive - 1
		pin:Hide()
		pin:ClearAllPoints()
		if pin.OnReleased then pin:OnReleased() end
		self.free[#self.free + 1] = pin
		return true
	end

	function pool:ReleaseAll()
		local list = {}
		for pin in pairs(self.active) do list[#list + 1] = pin end
		for _, pin in ipairs(list) do self:Release(pin) end
	end

	function pool:EnumerateActive() return pairs(self.active) end
	function pool:GetNumActive() return self.numActive end
	function pool:IsActive(pin) return self.active[pin] == true end

	map.pinPools[name] = pool
	return pool
end

--- An icon pin's parts: Icon over the whole pin, and Glow behind it when asked.
function PinPool.IconParts(size, glow)
	return function(pin)
		pin:SetSize(size, size)
		if glow then
			pin.Glow = pin:CreateTexture(nil, "BACKGROUND")
			pin.Glow:SetPoint("CENTER")
			pin.Glow:SetAlpha(0.55)
		end
		pin.Icon = pin:CreateTexture(nil, "ARTWORK")
		pin.Icon:SetAllPoints()
	end
end
