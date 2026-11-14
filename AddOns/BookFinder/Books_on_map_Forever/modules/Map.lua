-- Books on map (Forever): world map pins
local ADDON, ns = ...; ns = ns.Books; if ns.__skip then return end
local L = ns.L
local BOOKS, CONTINENTS = ns.BOOKS, ns.CONTINENTS

ns.DEFAULT_PIN_SIZE = 20
local pins, pinPool = {}, {}
local trail       -- frame holding the route trail, raised with the pins
local pinScale    -- size factor of the last draw (continent maps draw smaller pins)

-- OpenMap (seamless world map, docs/api.md in its repository): its API when the world map shows the
-- stitched map now, else nil. Version 2 brought CanvasFromWorldPos and ArtTopLevel
local function stitched()
  local api = OpenMapAPI
  if type(api) ~= "table" or api.major ~= 1 or (api.version or 0) < 2 then return end
  local ok, on = pcall(api.IsStitched)
  if ok and on then return api end
end

-- frame level for our pins: above OpenMap's stitched art when it's showing
-- (otherwise they're drawn under it and OpenMap only lifts them a frame later)
local function pinLevel(canvas)
  local level = canvas:GetFrameLevel() + 2000
  local api = stitched()
  if api then
    local ok, top = pcall(api.ArtTopLevel)
    if ok and type(top) == "number" and top + 2 > level then level = top + 2 end
  end
  return level
end

local function canvasScale()
  local scale = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer:GetCanvasScale() or 1
  if not scale or scale <= 0 then scale = 1 end
  return scale
end

-- Route trail: only the next few steps, drawn as soft dots that fade with each step further
-- away, and a single spark travelling along them toward the next books
local TRAIL_STEPS = 5     -- route segments shown (next book first)
local DOT_GAP = 12        -- screen pixels between dots
local DOT_SIZE = 8        -- screen pixels
local DOT_MAX = 150       -- dots per segment at most (spread out beyond that)
local SPARK_SIZE = 11     -- screen pixels
local SPARK_HALO = 2.2    -- its soft halo, times its size
local SPARK_SPEED = 110   -- screen pixels per second
local SPARK_LOOP = 5      -- seconds a trip takes at most (long trails are run faster)
local SPARK_PAUSE = 0.6   -- seconds between two trips
local TRAIL_SETTLE = 0.15  -- seconds without zooming before the trail is laid out again
local segs, dots, dotPool = {}, {}, {}
local segLen, pathLen = {}, 0   -- canvas units
local spark, sparkSpeed, sparkFade
local lastScale, settling = 0, false

local function releaseDots()
  for i = #dots, 1, -1 do
    dots[i]:Hide()
    dotPool[#dotPool + 1] = dots[i]
    dots[i] = nil
  end
end

-- the spark: where it is along the trail, every frame (one texture: cheap)
local function animateTrail()
  if pathLen <= 0 then spark:SetAlpha(0) return end
  local done = (GetTime() % (pathLen / sparkSpeed + SPARK_PAUSE)) * sparkSpeed
  if done > pathLen then spark:SetAlpha(0) return end
  spark:SetAlpha(math.min(1, done / sparkFade, (pathLen - done) / sparkFade))
  local at = done
  for i, sg in ipairs(segs) do
    local len = segLen[i]
    if at <= len or i == #segs then
      local f = len > 0 and math.min(1, at / len) or 0
      spark:ClearAllPoints()
      spark:SetPoint("CENTER", WorldMapFrame:GetCanvas(), "TOPLEFT",
        sg[1] + (sg[3] - sg[1]) * f, -(sg[2] + (sg[4] - sg[2]) * f))
      return
    end
    at = at - len
  end
end

-- lays the dots along the segments for the current zoom (gaps stay the same on screen)
local function layoutTrail()
  releaseDots()
  if not trail then return end
  if #segs == 0 then trail:Hide() return end
  local C = ns.Skin.C
  local canvas = WorldMapFrame:GetCanvas()
  local scale = canvasScale()
  local gap, size = DOT_GAP / scale, DOT_SIZE / scale
  local trim = (ns.db.pinSize or ns.DEFAULT_PIN_SIZE) * (pinScale or 1) * 0.75 / scale -- clear of the pins
  pathLen = 0
  for i, sg in ipairs(segs) do
    local dx, dy = sg[3] - sg[1], sg[4] - sg[2]
    local len = math.sqrt(dx * dx + dy * dy)
    segLen[i], pathLen = len, pathLen + len
    local usable = len - 2 * trim
    if usable > 0 then
      local n, step = math.floor(usable / gap), gap
      if n > DOT_MAX then n, step = DOT_MAX, usable / DOT_MAX end
      local off = trim + (usable - n * step) / 2
      local alpha = 0.85 * math.max(0.5, 1 - (sg[5] - 1) * 0.12)
      for k = 0, n do
        local at = off + k * step
        local d = table.remove(dotPool)
        if not d then
          d = trail:CreateTexture(nil, "ARTWORK")
          d:SetTexture(ns.Skin.MEDIA .. "Dot")
        end
        d:SetVertexColor(C.trim[1], C.trim[2], C.trim[3], alpha)
        d:SetSize(size, size)
        d:ClearAllPoints()
        d:SetPoint("CENTER", canvas, "TOPLEFT", sg[1] + dx * at / len, -(sg[2] + dy * at / len))
        d:Show()
        dots[#dots + 1] = d
      end
    end
  end

  if not spark then
    spark = CreateFrame("Frame", nil, trail)
    spark.core = spark:CreateTexture(nil, "OVERLAY")
    spark.core:SetTexture(ns.Skin.MEDIA .. "Dot")
    spark.core:SetAllPoints()
    spark.halo = spark:CreateTexture(nil, "BORDER")
    spark.halo:SetTexture(ns.Skin.MEDIA .. "Dot")
    spark.halo:SetBlendMode("ADD")
    spark.halo:SetPoint("CENTER")
  end
  local sz = SPARK_SIZE / scale
  spark:SetSize(sz, sz)
  spark.core:SetVertexColor(C.fill1[1], C.fill1[2], C.fill1[3], 1)
  spark.halo:SetSize(sz * SPARK_HALO, sz * SPARK_HALO)
  spark.halo:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.45)
  sparkSpeed = math.max(SPARK_SPEED / scale, pathLen / SPARK_LOOP)
  sparkFade = math.max(1e-6, math.min(pathLen / 6, 30 / scale))
  trail:Show()
  animateTrail()
end

local function settleTrail()
  local wait = TRAIL_SETTLE - (GetTime() - lastScale)
  if wait > 0.01 then C_Timer.After(wait, settleTrail) return end
  settling = false
  if WorldMapFrame:IsShown() then layoutTrail() end
end

-- position (0-1) of a book location on the displayed map, or nil
local rects = {}  -- [zone][continent] = { left, right, top, bottom } or false (they never change)
local function project(loc, mapID, onContinent)
  local x, y = loc[2] / 100, loc[3] / 100
  if loc[1] == mapID then return x, y end
  if onContinent then
    local byMap = rects[loc[1]]
    if not byMap then byMap = {}; rects[loc[1]] = byMap end
    local r = byMap[mapID]
    if r == nil then
      local l, rt, t, b = C_Map.GetMapRectOnMap(loc[1], mapID)
      r = l and rt ~= l and { l, rt, t, b } or false
      byMap[mapID] = r
    end
    if r then
      local left, right, top, bottom = r[1], r[2], r[3], r[4]
      return left + x * (right - left), top + y * (bottom - top)
    end
  end
end

-- position of a book location on OpenMap's stitched canvas (fractions of the map underneath, which
-- run past 0-1 into the zones either side of it), or nil when it can't be placed there
local worldOf = {}  -- [loc] = { continent, x, y } or false (they never change)
local function projectStitched(api, loc)
  local w = worldOf[loc]
  if w == nil then
    local c, x, y = ns.WorldPos(loc[1], loc[2] / 100, loc[3] / 100)
    w = c and { c, x, y } or false
    worldOf[loc] = w
  end
  if not w then return end
  local ok, x, y = pcall(api.CanvasFromWorldPos, w[1], w[2], w[3])
  if ok and type(x) == "number" and type(y) == "number" then return x, y end
end

-- a zone map shows full-size pins; continents and the world (OpenMap zoomed out) smaller ones
local function isZoomedOut(mapID)
  if CONTINENTS[mapID] then return true end
  local info = C_Map.GetMapInfo(mapID)
  local zone = Enum and Enum.UIMapType and Enum.UIMapType.Zone
  return info and type(info.mapType) == "number" and type(zone) == "number" and info.mapType < zone or false
end

local function acquirePin(canvas)
  local p = table.remove(pinPool)
  if not p then
    p = CreateFrame("Button", nil, canvas)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints()
    p.num = p:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    p.num:SetPoint("BOTTOMRIGHT", 4, -2)
    p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    p:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.book.name, 1, 0.82, 0)
      GameTooltip:AddLine(("%s  (%.1f, %.1f)"):format(self.loc[4], self.loc[2], self.loc[3]), 1, 1, 1)
      if self.step then GameTooltip:AddLine(L["Route step %d"]:format(self.step), 0.4, 0.8, 1) end
      GameTooltip:AddLine(L["Books: %d/%d"]:format(ns.CountDone(), #BOOKS), 0.7, 0.7, 0.7)
      ns.AddGroupTooltip(self.book)
      GameTooltip:AddLine(L["Shift-click: mark as collected"], 0.5, 1, 0.5)
      local hint = ns.WaypointHint()
      if hint then GameTooltip:AddLine(hint, 0.5, 1, 0.5) end
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        ns.Waypoint(self.loc, self.book.name)
      elseif IsShiftKeyDown() then
        GameTooltip:Hide()
        ns.SetDone(self.book, true)
      end
    end)
  end
  p:SetParent(canvas)
  return p
end

local function releasePins()
  for i = #pins, 1, -1 do
    local p = pins[i]
    p:Hide()
    p:ClearAllPoints()
    pins[i] = nil
    pinPool[#pinPool + 1] = p
  end
end

local drawnMap, drawnStitched -- what the last draw was laid out on (OpenMap's view callbacks compare)

-- BookFinder: on OpenMap's stitched map the books live in OpenMap's own icon layer, in its world, as its dungeons
-- and docks do: placed once, culled to the view, sized with its Icon size, and left alone while the map is dragged
-- and zoomed. (On the canvas they were all built again each time the map underneath changed, which it does with
-- every zone the view crosses.) Off the stitched map (dungeons, Blizzard's own) they are canvas pins as before.
local WORLD_SET, WORLD_LEVEL = "bookfinder_books", 40
local worldDirty = true            -- the books, their route steps or the settings changed since the layer was made
local worldUV = {}                 -- [loc] = { u, v } on OpenMap's world, or false (they never change)

local function openMapLayer()
  if not (BookFinder and BookFinder.Active and BookFinder.Active("OpenMap")) then return end
  local S = _G.OpenMap and _G.OpenMap.MapStitch
  if S and S.PinSet and S.AddPin and S.ClearPinSet and S.IsBuilt and S.IsBuilt() and stitched() then return S end
end

local function worldOf(loc)
  local uv = worldUV[loc]
  if uv == nil then
    local api = OpenMapAPI
    local ok, u, v = pcall(api.WorldFromMap, loc[1], loc[2] / 100, loc[3] / 100)
    uv = ok and type(u) == "number" and type(v) == "number" and { u, v } or false
    worldUV[loc] = uv
  end
  return uv
end

local function worldTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(self.book.name, 1, 0.82, 0)
  GameTooltip:AddLine(("%s  (%.1f, %.1f)"):format(self.loc[4], self.loc[2], self.loc[3]), 1, 1, 1)
  if self.step then GameTooltip:AddLine(L["Route step %d"]:format(self.step), 0.4, 0.8, 1) end
  GameTooltip:AddLine(L["Books: %d/%d"]:format(ns.CountDone(), #BOOKS), 0.7, 0.7, 0.7)
  ns.AddGroupTooltip(self.book)
  local hint = ns.WaypointHint()
  if hint then GameTooltip:AddLine(hint, 0.5, 1, 0.5) end
  GameTooltip:AddLine(L["Shift-click: mark as collected"], 0.5, 1, 0.5)
  GameTooltip:Show()
end

local function worldClick(self)
  GameTooltip:Hide()
  if IsShiftKeyDown() then ns.SetDone(self.book, true) else ns.Waypoint(self.loc, self.book.name) end
end

local function buildWorld(S)
  local set = S.PinSet(WORLD_SET, 1, WORLD_LEVEL)
  S.ClearPinSet(set)
  worldDirty = false
  if ns.db.hidden then return end
  local size = ns.db.pinSize or ns.DEFAULT_PIN_SIZE
  -- the route's next steps (BookFinder: drawn while the game's pin guides it too; its pin is only the next book)
  local route = ns.db.routeOn and ns.GetRoute and ns.GetRoute() or nil
  if route then
    local C = ns.Skin.C
    local prev
    for i = 1, math.min(#route, TRAIL_STEPS + 1) do
      local uv = worldOf(route[i].loc)
      if uv and prev then
        local alpha = 0.85 * math.max(0.5, 1 - (i - 2) * 0.12)
        S.AddLine(set, prev[1], prev[2], uv[1], uv[2], 3, C.trim[1], C.trim[2], C.trim[3], alpha)
      end
      prev = uv or prev
    end
  end
  for _, b in ipairs(BOOKS) do
    local mine = not ns.IsDone(b)
    if mine or ns.GroupNeeds(b) then
      for _, loc in ipairs(b.locs) do
        local uv = worldOf(loc)
        if uv then
          local pin = S.AddPin(set, uv[1], uv[2], { texture = b.icon and ("Interface\\Icons\\" .. b.icon) or ns.ICON, size = size })
          pin.book, pin.loc = b, loc
          pin.step = ns.RouteStep and ns.RouteStep(b, loc)
          if not pin.bfNum then
            pin.bfNum = pin:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            pin.bfNum:SetPoint("BOTTOMRIGHT", 4, -2)
          end
          pin.bfNum:SetText(route and pin.step and pin.step <= TRAIL_STEPS + 1 and pin.step or "")
          pin.Icon:SetDesaturated(not mine)
          pin:SetAlpha(mine and 1 or 0.8)
          pin:SetScript("OnEnter", worldTooltip)
          pin:SetScript("OnLeave", GameTooltip_Hide)
          pin.OnClick = worldClick
        end
      end
    end
  end
end

-- what the map shows now: OpenMap's layer on the stitched map (made again only when the books changed), else the
-- canvas pins. The map's own events (it changed, opened, zoomed; OpenMap's view moved) come here
local function draw()
  if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
  local S = openMapLayer()
  if S then
    if worldDirty or not S.GetPinSet(WORLD_SET) then buildWorld(S) end
    -- (no canvas pins or trail under it)
    if #pins > 0 or #segs > 0 then
      releasePins()
      wipe(segs)
      layoutTrail()
    end
    drawnMap, drawnStitched = WorldMapFrame:GetMapID(), true
    return
  end
  ns.DrawCanvas()
end

ns.OnMapEvent = draw   -- (the map changed, opened or moved: nothing about the books did)

-- the books, a setting or the route changed: draw them again
function ns.RefreshMap()
  worldDirty = true
  local S = openMapLayer()
  if not S and _G.OpenMap and _G.OpenMap.MapStitch and _G.OpenMap.MapStitch.GetPinSet then
    -- (not stitched now: OpenMap hides its layer itself; it is made again when it shows)
    local set = _G.OpenMap.MapStitch.GetPinSet(WORLD_SET)
    if set then _G.OpenMap.MapStitch.ClearPinSet(set) end
  end
  draw()
end

function ns.DrawCanvas()
  if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
  releasePins()
  wipe(segs)
  drawnMap, drawnStitched = nil, nil
  if ns.db.hidden then layoutTrail() return end
  local mapID = WorldMapFrame:GetMapID()
  if not mapID then layoutTrail() return end
  local canvas = WorldMapFrame:GetCanvas()
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = canvasScale()
  local onContinent = CONTINENTS[mapID]
  -- On OpenMap's stitched map the map underneath is only the zone the view is on, while the view
  -- shows its neighbours too: every book in view is placed through OpenMap, not just that zone's
  local om = stitched()
  drawnMap, drawnStitched = mapID, om ~= nil
  local function place(loc)
    if om then
      local x, y = projectStitched(om, loc)
      if x then return x, y end
    end
    return project(loc, mapID, onContinent)
  end
  pinScale = isZoomedOut(mapID) and 0.7 or 1
  local size = (ns.db.pinSize or ns.DEFAULT_PIN_SIZE) / scale * pinScale
  local level = pinLevel(canvas)

  for _, b in ipairs(BOOKS) do
    local mine = not ns.IsDone(b)
    if mine or ns.GroupNeeds(b) then
      for _, loc in ipairs(b.locs) do
        local x, y = place(loc)
        if x then
          local p = acquirePin(canvas)
          p.book, p.loc = b, loc
          p.step = ns.RouteStep and ns.RouteStep(b, loc)
          p.num:SetText(p.step and p.step <= TRAIL_STEPS + 1 and p.step or "") -- numbers only along the trail
          p.num:SetScale(1 / scale)
          p.tex:SetTexture(b.icon and ("Interface\\Icons\\" .. b.icon) or ns.ICON)
          p.tex:SetDesaturated(not mine) -- only needed by the group
          p:SetAlpha(mine and 1 or 0.8)
          p:SetSize(size, size)
          p:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
          p:SetFrameLevel(level)
          p:Show()
          pins[#pins + 1] = p
        end
      end
    end
  end

  -- the next steps of the route visible on this map (Shortest Path's line is the route while it guides it)
  if ns.db.routeOn and ns.GetRoute and not (ns.RouteGuided and ns.RouteGuided()) then
    if not trail then
      trail = CreateFrame("Frame", nil, canvas)
      trail:SetAllPoints(canvas)
      trail:SetScript("OnUpdate", animateTrail)
    end
    trail:SetFrameLevel(level - 2) -- (its spark one above: still under the pins)
    local route, prevX, prevY = ns.GetRoute()
    for i = 1, math.min(#route, TRAIL_STEPS + 1) do
      local x, y = place(route[i].loc)
      if x and prevX then segs[#segs + 1] = { prevX * w, prevY * h, x * w, y * h, i - 1 } end
      prevX, prevY = x, y
    end
  end
  layoutTrail()
end

-- zoom only: the pins stay where they are (canvas coordinates), just resized.
-- Rebuilding them on every zoom step made them flicker under map addons such as OpenMap
function ns.RescaleMap()
  if not WorldMapFrame or not WorldMapFrame:IsShown() or not pinScale then return end
  if openMapLayer() then return end   -- (OpenMap sizes its own layer)
  local canvas = WorldMapFrame:GetCanvas()
  local scale = canvasScale()
  local size = (ns.db.pinSize or ns.DEFAULT_PIN_SIZE) / scale * pinScale
  local level = pinLevel(canvas)
  for _, p in ipairs(pins) do
    p:SetSize(size, size)
    p.num:SetScale(1 / scale)
    if p:GetFrameLevel() < level then p:SetFrameLevel(level) end
  end
  if trail then trail:SetFrameLevel(level - 2) end
  -- the trail is laid out again once the zoom settles, not on every step of it
  lastScale = GetTime()
  if #segs > 0 and not settling then
    settling = true
    C_Timer.After(TRAIL_SETTLE, settleTrail)
  end
end

-- OpenMap: redraw when its stitched map comes and goes, or a pan moved the map underneath without the
-- map telling us; and offer our switches in its menu (and its button tray, when starred)
local function hookOpenMap()
  local api = OpenMapAPI
  if type(api) ~= "table" or api.major ~= 1 then return end
  local owner = {}
  if type(api.RegisterCallback) == "function" then
    api.RegisterCallback(owner, "OpenMap_StitchedChanged", function() draw() end)
    api.RegisterCallback(owner, "OpenMap_ViewChanged", function()
      if not WorldMapFrame:IsShown() then return end
      if (stitched() ~= nil) ~= drawnStitched or (not drawnStitched and WorldMapFrame:GetMapID() ~= drawnMap) then draw() end
    end)
  end
  if type(api.RegisterMenuToggle) == "function" then
    local section = L["Library books"]
    pcall(api.RegisterMenuToggle, ADDON, {
      id = "pins", label = L["Show on the map"], icon = ns.ICON, section = section,
      get = function() return not ns.db.hidden end,
      set = function(on) ns.db.hidden = not on; ns.Refresh() end,
    })
    -- (BookFinder: the route is started and stopped in the books tab, where its stops are: not a switch here too)
    if not (BookFinder and BookFinder.OpenBooks) then pcall(api.RegisterMenuToggle, ADDON, {
      id = "route", label = L["Optimized route"], icon = "Interface\\Icons\\Ability_Tracking", section = section,
      get = function() return ns.db.routeOn and true or false end,
      set = function(on) ns.ToggleRoute(on and true or false) end,
    }) end
  end
end

function ns.InitMap()
  -- (the map only: map addons such as OpenMap change the map underneath on every pan)
  hooksecurefunc(WorldMapFrame, "OnMapChanged", function() draw() end)
  WorldMapFrame:HookScript("OnShow", function() draw() end)
  if WorldMapFrame.OnCanvasScaleChanged then
    hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", ns.RescaleMap)
  end
  hookOpenMap()
end
