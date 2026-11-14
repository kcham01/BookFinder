-- The books on the world map and the minimap.
--
-- Each missing book is a pin at each of its places, with the book's own icon (books.mapSize, 70% on continent maps).
-- Books only the group still needs show greyed and a little faded. With the route on, its next five steps carry
-- their number. No line is drawn between them. Hover: the book, its place and coordinates, the route step, the count,
-- the group. Right-click (or Ctrl-click) puts the map pin on it; Shift-click marks it collected.

local _, BF = ...
local L = BF.L

local Books = BF.Books
local BookMap = {}
BF.BookMap = BookMap

local TEMPLATE = "BookFinderBookPinTemplate"

-- What shows ----------------------------------------------------------------------------------------------------

--- "mine" (the player still needs it), "group" (only a group member does), or nil (not shown).
function BookMap:Shows(book)
	if not Books:IsDone(book) then
		if BF:Get("books.onlyMyLevel") and not Books:ForMyLevel(book) then return nil end
		return "mine"
	end
	if BF:Get("books.groupMissing") and #Books:MembersMissing(book) > 0 then return "group" end
	if not BF:Get("books.hideCollected") then return "done" end
	return nil
end

-- Tooltip and clicks (world map and minimap) -----------------------------------------------------------------------

function BookMap:ShowTooltip(owner, book, place, yards)
	local tip = GameTooltip
	tip:SetOwner(owner, "ANCHOR_RIGHT")
	tip:AddLine(Books:Name(book), 1, 0.82, 0)
	local where = L[book.place or ""] ~= "" and L[book.place] or BF.Zones:MapName(place.map) or ""
	tip:AddDoubleLine(where, BF.Zones:FormatCoords(place.x, place.y), 1, 1, 1, 0.7, 0.7, 0.7)
	if book.hint then tip:AddLine(L[book.hint], 0.8, 0.8, 0.8, true) end
	if yards then tip:AddLine(("%d %s"):format(math.floor(yards + 0.5), L["yd"]), 0.7, 0.7, 0.7) end
	local step = BF.BookRoute and BF.BookRoute:StepOf(book)
	if step then tip:AddLine(L["Route step %d"]:format(step), 0.4, 0.8, 1) end
	tip:AddLine(L["Books: %d/%d"]:format(Books:DoneCount(), Books:Count()), 0.7, 0.7, 0.7)
	if next(Books.group) then
		tip:AddLine(" ")
		local names = {}
		for name in pairs(Books.group) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do
			local has = Books:MemberHas(name, book)
			tip:AddDoubleLine(name, has and L["collected"] or L["missing"], 1, 1, 1, has and 0.3 or 1, has and 1 or 0.3, 0.3)
		end
	end
	tip:AddLine(" ")
	tip:AddLine(L["Shift-click: mark as collected"], 0.5, 0.5, 0.5)
	tip:AddLine(L["Right-click: map pin"], 0.5, 0.5, 0.5)
	tip:Show()
end

function BookMap:Click(book, place, button)
	if button == "RightButton" or (button == "LeftButton" and IsControlKeyDown()) then
		BF.Waypoint:Set(place.map, place.x, place.y, Books:Name(book), L[book.place or ""])
	elseif button == "LeftButton" and IsShiftKeyDown() then
		Books:Tick(book, true)
	end
end

-- World map --------------------------------------------------------------------------------------------------------

local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
BookMap.Provider = Provider

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function Provider:RefreshAllData()
	self:RemoveAllData()
	if not BF:Reached("login") or not BF:Get("books.map") then return end
	local map = self:GetMap():GetMapID()
	if not map then return end
	local info = C_Map.GetMapInfo(map)
	local continent = info and info.mapType and Enum.UIMapType and info.mapType <= Enum.UIMapType.Continent
	for _, book in ipairs(Books.list) do
		local shows = BookMap:Shows(book)
		if shows then
			for _, place in ipairs(Books:Places(book)) do
				local x, y = BF.Zones:Translate(place.map, place.x, place.y, map)
				if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
					self:GetMap():AcquirePin(TEMPLATE, book, place, x, y, shows, continent)
				end
			end
		end
	end
end

BookFinderBookPinMixin = CreateFromMixins(MapCanvasPinMixin)

function BookFinderBookPinMixin:OnLoad()
	self:SetScalingLimits(1, 1.0, 1.15)
	if self.SetPassThroughButtons and not InCombatLockdown() then pcall(self.SetPassThroughButtons, self) end
end

function BookFinderBookPinMixin:OnAcquired(book, place, x, y, shows, continent)
	self.book, self.place = book, place
	local size = BF:Get("books.mapSize") * (continent and 0.7 or 1)
	self:SetSize(size, size)
	self.Icon:SetTexture(Books:Icon(book))
	self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local group = shows == "group"
	if self.Icon.SetDesaturated then self.Icon:SetDesaturated(group or shows == "done") end
	self:SetAlpha(group and 0.7 or 1)
	local step = BF.BookRoute and BF.BookRoute:StepOf(book)
	self.Step:SetText(step and step <= 5 and tostring(step) or "")
	self:SetPosition(x, y)
end

function BookFinderBookPinMixin:OnReleased()
	self.book, self.place = nil, nil
end

function BookFinderBookPinMixin:OnMouseEnter()
	BookMap:ShowTooltip(self, self.book, self.place)
end

function BookFinderBookPinMixin:OnMouseLeave()
	GameTooltip:Hide()
end

function BookFinderBookPinMixin:OnMouseUp(button)
	BookMap:Click(self.book, self.place, button)
end

local function refreshWorldMap()
	if WorldMapFrame and WorldMapFrame:IsShown() then Provider:RefreshAllData() end
end

-- Minimap --------------------------------------------------------------------------------------------------------
--
-- Few enough to look at every place each update. The route's next book stays on the minimap's rim when it is out of
-- range, pointing the way.

local pool, active = {}, {}

local function acquire()
	local f = table.remove(pool)
	if not f then
		f = CreateFrame("Frame", nil, Minimap)
		f:SetFrameStrata("MEDIUM")
		f.Icon = f:CreateTexture(nil, "ARTWORK")
		f.Icon:SetAllPoints()
		f.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f:EnableMouse(true)
		f:SetScript("OnEnter", function(self) BookMap:ShowTooltip(self, self.book, self.place, self.yards) end)
		f:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f:SetScript("OnMouseUp", function(self, button) BookMap:Click(self.book, self.place, button) end)
	end
	f:Show()
	active[#active + 1] = f
	return f
end

local function releaseAll()
	for i = #active, 1, -1 do
		active[i]:Hide()
		pool[#pool + 1] = active[i]
		active[i] = nil
	end
end

local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }

local function minimapYards()
	local zoom = Minimap:GetZoom()
	local indoors = GetCVar("minimapZoom") + 0 ~= zoom and GetCVar("minimapInsideZoom") + 0 == zoom
	return (indoors and INDOOR or OUTDOOR)[zoom] or OUTDOOR[0]
end

local function updateMinimap()
	releaseAll()
	if not BF:Get("books.minimap") or not Minimap:IsVisible() then return end
	local instance, px, py = BF.Zones:PlayerWorld()
	if not instance then return end
	local yards = minimapYards()
	local radius = yards / 2
	local ppy = Minimap:GetWidth() / yards
	local rotate = GetCVar("rotateMinimap") == "1"
	local facing = rotate and (GetPlayerFacing() or 0) or 0
	local cs, sn = math.cos(facing), math.sin(facing)
	local size = BF:Get("books.minimapSize")
	local nextBook = BF.BookRoute and BF.BookRoute:Next()
	for _, book in ipairs(Books.list) do
		local shows = BookMap:Shows(book)
		if shows then
			for _, place in ipairs(Books:Places(book)) do
				local inst, wx, wy = BF.Zones:ToWorld(place.map, place.x, place.y)
				if inst == instance then
					local north, west = wx - px, wy - py
					local dist = math.sqrt(north * north + west * west)
					local onRim = dist > radius and nextBook == book
					if dist <= radius or onRim then
						local right, up = -west, north
						if rotate then right, up = right * cs + up * sn, -right * sn + up * cs end
						if onRim then
							local k = (radius - 4) / dist
							right, up = right * k, up * k
						end
						local f = acquire()
						f.book, f.place, f.yards = book, place, dist
						f:SetSize(size, size)
						f.Icon:SetTexture(Books:Icon(book))
						if f.Icon.SetDesaturated then f.Icon:SetDesaturated(shows ~= "mine") end
						f:SetAlpha(shows == "group" and 0.7 or (onRim and 0.8 or 1))
						f:ClearAllPoints()
						f:SetPoint("CENTER", Minimap, "CENTER", right * ppy, up * ppy)
					end
				end
			end
		end
	end
end
BookMap.UpdateMinimap = updateMinimap

local ticker = 0
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
	ticker = ticker + elapsed
	if ticker < 0.1 then return end
	ticker = 0
	updateMinimap()
end)
driver:Hide()

BF:At("login", function()
	if WorldMapFrame and WorldMapFrame.AddDataProvider then WorldMapFrame:AddDataProvider(Provider) end
	for _, m in ipairs({ "BF_BOOKS_CHANGED", "BF_BOOKS_GROUP_CHANGED", "BF_BOOK_ROUTE_CHANGED" }) do
		BF:Listen(m, refreshWorldMap)
	end
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key:find("^books%.") then refreshWorldMap() end end)
end, 71)

BF:At("world", function() driver:Show() end)
