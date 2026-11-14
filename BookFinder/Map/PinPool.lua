-- Pins for the game's map canvas, made in Lua (no XML template).
--
-- The canvas makes pins through a pool per template name (map.pinPools[name]); with an XML template it must be able to
-- look the template up, and WoW: Forever's canvas asserts when it can't. So BookFinder puts its own pool under its own
-- name in map.pinPools (as the long-standing map pin libraries do): the canvas then only calls the pool's Acquire,
-- Release, ReleaseAll and EnumerateActive, and never looks a template up.

local _, BF = ...

local PinPool = {}
BF.PinPool = PinPool

--- Registers a pool `name` on `map` whose pins are made by build(pin) and get `mixin`.
function PinPool:Register(map, name, mixin, build)
	map.pinPools = map.pinPools or {}
	if map.pinPools[name] then return end
	local canvas = map.GetCanvas and map:GetCanvas() or map
	local pool = { active = {}, free = {}, numActive = 0 }

	function pool:Acquire()
		local pin = table.remove(self.free)
		local new = false
		if not pin then
			pin = CreateFrame("Frame", nil, canvas)
			Mixin(pin, mixin)
			pin.pinTemplate, pin.owningMap = name, map
			build(pin)
			if pin.OnLoad then pin:OnLoad() end
			new = true
		end
		self.active[pin] = true
		self.numActive = self.numActive + 1
		pin:Show()
		return pin, new
	end

	function pool:Release(pin)
		if not self.active[pin] then return false end
		self.active[pin] = nil
		self.numActive = self.numActive - 1
		if pin.OnReleased then pin:OnReleased() end
		pin:Hide()
		pin:ClearAllPoints()
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
end

--- Mouse on: the canvas wires it. It asserts that a new pin has no OnEnter/OnLeave of its own (Blizzard_MapCanvas
--- line 309 on WoW: Forever), then routes the mouse to the pin's OnMouseEnter, OnMouseLeave, OnMouseDown, OnMouseUp
--- and, for a click released over the pin, OnMouseClickAction(button). So the pin only defines those methods.
function PinPool:Wire(pin)
	pin:EnableMouse(true)
end
