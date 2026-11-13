"""Differential load test: the three addons standalone vs. merged into BookFinder, in one stubbed client.

Usage:  python3 tools/offline-test/merged.py [standalone|merged|shadow|diff]   (default: diff)
Needs:  pip install lupa; python3 tools/build.py --no-textures first (it reads build/)

Each mode loads ForeverCore and then the addons, fires ADDON_LOADED / PLAYER_LOGIN / PLAYER_ENTERING_WORLD,
runs timers, a combat cycle and every part's slash commands, and records errors. "diff" runs standalone and
merged and fails on any error the merged build has that the standalone addons don't: the stub (stub.lua, from
OpenMap's tools/offline-test, MIT) has gaps that both hit the same way, so only new errors are the merge's.
"shadow" is merged with the standalone OpenMap reported as installed and enabled: BookFinder's OpenMap must stand
aside without breaking the rest. Like OpenMap's own test, this can't build the stitched map or catch layout
problems: those need the game.
"""
import os
import re
import sys

import lupa.lua51 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(ROOT, "src")
BUILD = os.path.join(ROOT, "build")

# globals the addons create: nil until they do (the stub answers unknown names with proxies)
OWN_GLOBALS = [
    "OpenMapDB", "OpenMapCharDB", "ShortestPathForeverDB", "ShortestPathForeverCharDB", "BooksOnMapForeverGlobal",
    "BooksOnMapForeverDB", "ShortestPathForever", "ShortestPathForeverPathData", "ForeverCore", "ForeverCoreDB",
    "ForeverCoreCharDB", "BookFinder", "BookFinderDB", "ForeverTrackerHost", "OpenMapAPI", "OpenMap", "TomTom", "Questie", "QuestieLoader", "RXPCData",
    "Guidelime", "RXP", "Zygor", "ZGV", "ForeverCoreAPI", "WorldMapFrame_OnShow",
]


# The parts working together, on stand-ins for the map and the APIs the stub can't run
INTEGRATION = r"""function(root)
    local out = {}
    local function want(cond, msg) if not cond then out[#out + 1] = "integration: " .. msg end end
    local B = root.Books
    -- (everything replaced here is put back at the end: the parts' timers keep running after)
    local saved = {}
    for _, k in ipairs({ "GetBestMapForUnit", "GetPlayerMapPosition", "GetMapRectOnMap", "GetMapInfo", "GetWorldPosFromMapPos" }) do saved[k] = C_Map[k] end
    local savedVector = CreateVector2D

    -- Books -> Shortest Path: its API version 2 is taken, single book and whole route go to it
    want(B.WaypointProvider() == "Shortest Path", "Books doesn't send waypoints to Shortest Path's API v" .. tostring(ShortestPathForever.API.version))
    want(B.RouteWaypointProvider() == "Shortest Path", "Books doesn't send its route to Shortest Path")
    local sent
    local api = ShortestPathForever.API
    local navigate, estimate = api.NavigateRoute, api.Estimate
    api.NavigateRoute = function(owner, stops) sent = { owner = owner, n = #stops, first = stops[1] } return true end
    B.SendRouteWaypoints({ { book = B.BOOKS[1], loc = B.BOOKS[1].locs[1] }, { book = B.BOOKS[2], loc = B.BOOKS[2].locs[1] } })
    want(sent and sent.n == 2 and sent.first.kind == "pickup" and sent.first.map == B.BOOKS[1].locs[1][1], "the route didn't reach NavigateRoute as stops")
    api.NavigateRoute = navigate

    -- Books' tracker: Shortest Path's travel time
    C_Map.GetBestMapForUnit = function() return 1429 end
    C_Map.GetPlayerMapPosition = function() return { x = 0.5, y = 0.5, GetXY = function(self) return self.x, self.y end } end
    api.Estimate = function() return 754 end
    want(B.TravelSeconds(B.BOOKS[3].locs[1]) == 754, "no travel time from Shortest Path")
    api.Estimate = estimate

    -- Books on OpenMap's stitched map: a book of every zone in view, not only the zone underneath
    local canvas = CreateFrame("Frame", nil, UIParent)
    canvas.GetWidth = function() return 1000 end
    canvas.GetHeight = function() return 700 end
    canvas.GetFrameLevel = function() return 1 end
    local wm = WorldMapFrame
    wm.GetCanvas = function() return canvas end
    wm.GetMapID = function() return 1429 end        -- Elwynn underneath
    wm.ScrollContainer = wm.ScrollContainer or CreateFrame("Frame", nil, wm)
    wm.ScrollContainer.GetCanvasScale = function() return 1 end
    wm:Show()
    C_Map.GetMapRectOnMap = function() return nil end
    C_Map.GetMapInfo = function(id) return { mapID = id, mapType = 3 } end
    CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
    C_Map.GetWorldPosFromMapPos = function(map, v) return 0, { x = map + v.x, y = v.y, GetXY = function(self) return self.x, self.y end } end
    local O = OpenMapAPI
    local isStitched, toCanvas, top = O.IsStitched, O.CanvasFromWorldPos, O.ArtTopLevel
    O.IsStitched = function() return true end
    O.ArtTopLevel = function() return 5000 end
    O.CanvasFromWorldPos = function(c, x, y) return (x - 1429) * 0.01, y end   -- every zone somewhere on the canvas
    B.db.hidden = nil
    B.RefreshMap()
    local zones, levelOK, n = {}, true, 0
    for _, f in ipairs(FRAMES) do
        if f.book and f.loc and f:IsShown() then
            n = n + 1
            zones[f.loc[1]] = true
            if (f:GetFrameLevel() or 0) <= 5000 then levelOK = false end
        end
    end
    local count = 0 for _ in pairs(zones) do count = count + 1 end
    want(n > 0 and count > 1, ("stitched: books of %d zone(s) shown, expected several"):format(count))
    want(levelOK, "stitched: a book pin under OpenMap's art")
    O.IsStitched = function() return false end
    B.RefreshMap()
    zones = {}
    for _, f in ipairs(FRAMES) do if f.book and f:IsShown() then zones[f.loc[1]] = true end end
    count = 0 for k in pairs(zones) do count = count + 1 want(k == 1429, "unstitched: a book of another zone on Elwynn's map") end
    want(count == 1, "unstitched: Elwynn's books aren't shown")
    O.IsStitched, O.CanvasFromWorldPos, O.ArtTopLevel = isStitched, toCanvas, top

    -- On the stitched map the books go into OpenMap's own icon layer (its world space), once: a map swap while the
    -- map is dragged (the map underneath following the view) must not build them again
    local Sx = root.OpenMap.MapStitch
    local savedS = {}
    for _, k in ipairs({ "IsBuilt", "PinSet", "AddPin", "AddLine", "ClearPinSet", "GetPinSet" }) do savedS[k] = Sx[k] end
    local layer, adds, clears = nil, 0, 0
    Sx.IsBuilt = function() return true end
    Sx.PinSet = function(key) layer = layer or { key = key, pins = {} } return layer end
    Sx.GetPinSet = function(key) return layer and layer.key == key and layer or nil end
    Sx.AddPin = function(set, u, v, look)
        adds = adds + 1
        local pin = CreateFrame("Button")
        pin.Icon = pin:CreateTexture()
        set.pins[#set.pins + 1] = pin
        return pin
    end
    Sx.AddLine = function() end
    Sx.ClearPinSet = function(set) clears = clears + 1 wipe(set.pins) end
    local worldFrom = O.WorldFromMap
    O.IsStitched = function() return true end
    O.WorldFromMap = function(map, x, y) return (map - 1400) / 60 + x / 60, y end
    wm:Show()
    B.RefreshMap()
    local built, addsBefore, clearsBefore = #layer.pins, adds, clears
    want(built > 1, "stitched: books weren't put in OpenMap's icon layer")
    local onCanvas = 0
    for _, f in ipairs(FRAMES) do if f.book and f:IsShown() and f:GetParent() == canvas then onCanvas = onCanvas + 1 end end
    want(onCanvas == 0, "stitched: books drawn on the canvas as well as in OpenMap's layer")
    wm.GetMapID = function() return 1436 end   -- (Westfall: the view crossed into it)
    B.OnMapEvent()
    B.OnMapEvent()
    want(adds == addsBefore and clears == clearsBefore,
        ("stitched: a map swap while dragging built the books again (%d pins added, %d clears)"):format(adds - addsBefore, clears - clearsBefore))
    B.db.hidden = true
    B.RefreshMap()
    want(#layer.pins == 0, "stitched: hiding the books left them in OpenMap's layer")
    B.db.hidden = nil
    B.RefreshMap()
    want(#layer.pins == built, ("stitched: the books didn't come back (%d of %d)"):format(#layer.pins, built))
    for k, f in pairs(savedS) do Sx[k] = f end
    O.IsStitched, O.WorldFromMap = isStitched, worldFrom
    wm.GetMapID = function() return 1429 end
    wm:Hide()   -- (the stand-in map is only enough for Books' pins: Shortest Path's redraw needs the real one)

    -- OpenMap's menu: Books' and Shortest Path's switches, and they work
    local rows = {}
    local wmod = root.OpenMap.modules and root.OpenMap.modules.worldmap
    if wmod and wmod.ExtraMenuRows then
        for _, r in ipairs(wmod.ExtraMenuRows(function(label, id, icon, get, set) return { id = id, get = get, set = set } end)) do
            if r.id then rows[r.id] = r end
        end
    end
    for _, id in ipairs({ "pins", "route", "spf.pins", "spf.transit", "spf.portals", "spf.mapFlightMasters" }) do
        want(rows["ext.BookFinder." .. id], "no OpenMap menu switch " .. id)
    end
    local r = rows["ext.BookFinder.pins"]
    if r then r.set(false) want(B.db.hidden and not r.get(), "the books switch didn't hide the books") r.set(true) end
    r = rows["ext.BookFinder.spf.portals"]
    if r then
        local was = root.SPF.db.portals
        r.set(not was) want(root.SPF.db.portals == not was, "the portals switch didn't change Shortest Path's setting") r.set(was)
    end
    -- One settings window: one category in the AddOns list, BookFinder, holding every part's pages
    local names = {}
    for _, c in ipairs(SETTINGS.listed) do names[#names + 1] = c.name end
    want(#SETTINGS.listed == 1 and SETTINGS.listed[1].name == "BookFinder",
        "settings: the AddOns list has " .. table.concat(names, ", ") .. " (expected BookFinder alone)")
    local top = {}
    for _, c in ipairs(SETTINGS.top) do top[#top + 1] = c.name end
    want(#SETTINGS.top == 1, "settings: top-level categories made: " .. table.concat(top, ", "))
    local pages = {}
    for _, c in ipairs(SETTINGS.listed[1] and SETTINGS.listed[1].subs or {}) do pages[c.name] = true end
    for _, page in ipairs({ "World map", "Map marks", "Transport", "Travel journal", "Guidance", "Party mage portals",
            "Alerts", "Interface", "Books" }) do
        want(pages[page], "settings: no " .. page .. " page in BookFinder's window")
    end
    want(BookFinder.OpenSettings("map") and BookFinder.OpenSettings("books") and BookFinder.OpenSettings(), "settings: a page can't be opened")

    -- One minimap button and one launcher
    local LDBI = LibStub("LibDBIcon-1.0", true)
    local buttons = {}
    for name in pairs(LDBI and LDBI.objects or {}) do buttons[#buttons + 1] = name end
    want(#buttons == 1 and buttons[1] == "BookFinder", "minimap buttons: " .. table.concat(buttons, ", "))
    want(not rawget(_G, "OpenMapMinimapButton") and not rawget(_G, "ShortestPathForeverOptionsButton"), "another part made its own minimap button")
    local LDB = LibStub("LibDataBroker-1.1", true)
    local launchers = {}
    for name in LDB:DataObjectIterator() do launchers[#launchers + 1] = name end
    want(#launchers == 1 and launchers[1] == "BookFinder", "broker launchers: " .. table.concat(launchers, ", "))

    -- Nothing on the map twice: OpenMap leaves the docks, flight masters and Shortest Path's townsfolk to it
    local wm = root.OpenMap.modules and root.OpenMap.modules.worldmap
    want(wm and wm.SUPERSEDED and wm.SUPERSEDED.boats and wm.SUPERSEDED.flight, "OpenMap still owns docks or flight masters")
    want(wm and wm.db and wm.db.boats == false and wm.db.zeppelins == false and wm.db.flight == false,
        "OpenMap's docks or flight masters are still on")
    local kinds = {}
    for _, k in ipairs(wm and wm.TOWNSFOLK or {}) do kinds[k.key] = true end
    want(not kinds.vendor and not kinds.innkeeper and not kinds.classTrainer, "OpenMap still draws vendors, inns or trainers")
    want(kinds.mailbox and kinds.spirit and kinds.rare, "OpenMap lost mailboxes, spirit healers or rares")
    local panelIDs = {}
    if wm and wm.ExtraMenuRows then end
    want(wm and wm.TravelShown and wm.TravelShown("boats") == (root.SPF.db.pins ~= false), "the airships don't follow Shortest Path's boats switch")

    -- One guidance: Books' tracker steps aside while Shortest Path guides the route
    WorldMapFrame.EnumeratePinsByTemplate = false   -- (the stub's map answers every method; Shortest Path's quest pins look for this one)
    local api = ShortestPathForever.API
    local nav, cur = api.NavigateRoute, api.CurrentStop
    api.NavigateRoute = function() return true end
    api.CurrentStop = function() return 1 end
    B.ToggleRoute(true)
    local tracker = _G.BooksOnMapForeverRoute
    want(tracker and not tracker:IsShown(), "Books' route tracker shows while Shortest Path guides the route")
    api.CurrentStop = function() return nil end
    B.OnGuidanceChanged()
    want(tracker and tracker:IsShown(), "Books' tracker didn't come back when Shortest Path stopped guiding")
    want(B.GetRoute and #B.GetRoute() > 0, "no route was built to guide")

    -- The book list opens (the gear button that replaced its language picker has no Refresh)
    local okList, errList = pcall(B.ToggleOptions)
    want(okList, "the book list doesn't open: " .. tostring(errList))
    if okList then pcall(B.ToggleOptions) end

    -- Flight points: learned from the game's list when it marks some as undiscovered, and not when it lists all as found
    local S = root.SPF
    local mine
    for id, node in pairs(S.TaxiNodes or {}) do
        if not node.faction or node.faction == UnitFactionGroup("player") then mine = id break end
    end
    local taxiMap = C_TaxiMap
    C_TaxiMap = { GetTaxiNodesForMap = function() return { { nodeID = mine, isUndiscovered = false } } end }
    S.charDB.taxi[mine] = nil
    want(BookFinder.LearnFlights() == 0 and not S.charDB.taxi[mine], "flights learned from a list that marks none undiscovered")
    C_TaxiMap = { GetTaxiNodesForMap = function()
        return { { nodeID = mine, isUndiscovered = false }, { nodeID = 999999, isUndiscovered = true } }
    end }
    want(mine and BookFinder.LearnFlights() == 1 and S.charDB.taxi[mine], "a flight point the game lists as found wasn't learned")
    S.charDB.taxi[mine] = nil
    C_TaxiMap = taxiMap
    B.ToggleRoute(false)
    api.NavigateRoute, api.CurrentStop = nav, cur
    for k, f in pairs(saved) do C_Map[k] = f end
    CreateVector2D = savedVector
    return out
end"""


def toc_entries(toc_path):
    out = []
    for line in open(toc_path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        while re.search(r"\s*\[[^\]]*\]\s*$", line):
            line = re.sub(r"\s*\[[^\]]*\]\s*$", "", line)
        out.extend(expand(os.path.dirname(toc_path), line.replace("\\", os.sep)))
    return out


def expand(base, rel):
    path = os.path.join(base, rel)
    if rel.endswith(".xml"):
        files = []
        text = re.sub(r"<!--.*?-->", "", open(path, encoding="utf-8").read(), flags=re.S)
        for m in re.finditer(r'<(Script|Include)\s+file="([^"]+)"', text):
            files.extend(expand(base, os.path.join(os.path.dirname(rel), m.group(2).replace("\\", os.sep))))
        return files
    return [rel]


def run(mode):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute(open(os.path.join(HERE, "stub.lua"), encoding="utf-8").read())
    L.execute("""
        for _, k in ipairs({ %s }) do NIL_GLOBALS[k] = true end
        -- the retail-engine client's secret-value helpers: plain values here, so code past them runs
        NIL_GLOBALS.canaccessvalue, NIL_GLOBALS.issecretvalue = nil, nil
        -- WoW's xpcall passes its extra arguments on, as Lua 5.2's does (AceGUI relies on it); 5.1's doesn't
        local xpcall51 = xpcall
        xpcall = function(f, handler, ...)
            local n, args = select("#", ...), { ... }
            return xpcall51(function() return f(unpack(args, 1, n)) end, handler)
        end
        -- font objects (Books' skin makes its own)
        CreateFont = function(name)
            local f = CreateFrame("Frame", name)
            f.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end
            return f
        end
        canaccessvalue = function() return true end
        canaccessallvalues = function() return true end
        issecretvalue = function() return false end
        -- Blizzard's settings panel, recording what is made: SETTINGS.top = categories made at the top level,
        -- SETTINGS.listed = those added to the AddOns list; each category keeps its subcategories (names)
        local function object()
            return setmetatable({}, { __index = function(_, k)
                if type(k) == "number" then return nil end
                return function() return object() end
            end })
        end
        SETTINGS = { top = {}, listed = {}, nextID = 0 }
        local function Category(name, parent)
            SETTINGS.nextID = SETTINGS.nextID + 1
            local c = { name = name, ID = SETTINGS.nextID, subs = {}, parent = parent }
            function c:GetID() return self.ID end
            function c:GetName() return self.name end
            function c:GetSubcategories() return self.subs end
            if parent then parent.subs[#parent.subs + 1] = c else SETTINGS.top[#SETTINGS.top + 1] = c end
            SETTINGS.byID = SETTINGS.byID or {}
            SETTINGS.byID[c.ID] = c
            return c
        end
        -- what goes on each page, recorded (mode "dump" draws them): settings, and the rows made from them
        local function record(t)
            return setmetatable(t, { __index = function(_, k)
                if type(k) == "number" then return nil end
                return function() return object() end
            end })
        end
        local byVariable = {}
        local function Setting(variable, key, tbl, varType, name, default, get, set)
            local st = record({ variable = variable, key = key, tbl = tbl, varType = varType, name = name, default = default, get = get, set = set })
            st.GetValue = function(self)
                local get, tbl, key = rawget(self, "get"), rawget(self, "tbl"), rawget(self, "key")
                if get then return get() end
                local v = tbl and key and tbl[key]
                if v == nil then return rawget(self, "default") end
                return v
            end
            st.SetValue = function(self, v)
                local set, tbl, key = rawget(self, "set"), rawget(self, "tbl"), rawget(self, "key")
                if set then set(v) elseif tbl and key then tbl[key] = v end
                local cb = rawget(self, "callback")
                if cb then pcall(cb, nil, self, v) end
            end
            st.SetValueChangedCallback = function(self, fn) self.callback = fn end
            if variable then byVariable[variable] = st end
            return st
        end
        local known = {
            VarType = { Boolean = "boolean", Number = "number", String = "string" },
            RegisterAddOnSetting = function(_, variable, key, tbl, varType, name, default)
                return Setting(variable, key, tbl, varType, name, default)
            end,
            RegisterProxySetting = function(_, variable, varType, name, default, get, set)
                return Setting(variable, nil, nil, varType, name, default, get, set)
            end,
            GetSetting = function(variable) return byVariable[variable] end,
            RegisterInitializer = function(c, init) c.items = c.items or {} c.items[#c.items + 1] = init end,
            CreateCheckboxInitializer = function(setting, _, tooltip) return record({ kind = "checkbox", setting = setting, tooltip = tooltip }) end,
            CreateSliderInitializer = function(setting, options, tooltip) return record({ kind = "slider", setting = setting, options = options, tooltip = tooltip }) end,
            CreateDropdownInitializer = function(setting, options, tooltip) return record({ kind = "dropdown", setting = setting, options = options, tooltip = tooltip }) end,
            CreateSliderOptions = function(min, max, step)
                local o = record({ min = min, max = max, step = step })
                o.SetLabelFormatter = function(self, _, fn) self.fmt = fn end
                return o
            end,
            CreateControlTextContainer = function()
                local c = record({ data = {} })
                c.Add = function(self, value, label, tooltip) self.data[#self.data + 1] = { value = value, label = label, tooltip = tooltip } end
                c.GetData = function(self) return self.data end
                return c
            end,
            RegisterVerticalLayoutCategory = function(name) return Category(name) end,
            RegisterCanvasLayoutCategory = function(_, name) return Category(name) end,
            RegisterVerticalLayoutSubcategory = function(parent, name) return Category(name, parent) end,
            RegisterCanvasLayoutSubcategory = function(parent, _, name) return Category(name, parent) end,
            RegisterAddOnCategory = function(c) SETTINGS.listed[#SETTINGS.listed + 1] = c end,
            GetCategory = function(id) return SETTINGS.byID and SETTINGS.byID[id] end,
        }
        Settings = setmetatable(known, { __index = function() return function() return object() end end })
        CreateSettingsButtonInitializer = function(name, text, onClick, tooltip)
            return setmetatable({ kind = "button", name = name, buttonText = text, tooltip = tooltip, onClick = onClick },
                { __index = function(_, k) if type(k) ~= "number" then return function() return object() end end end })
        end
        CreateSettingsListSectionHeaderInitializer = function(name)
            return setmetatable({ kind = "header", name = name },
                { __index = function(_, k) if type(k) ~= "number" then return function() return object() end end end })
        end
        MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
        -- LibDBIcon registrations, by name (the minimap buttons)
        MINIMAP_BUTTONS = {}
    """ % ", ".join('"%s"' % g for g in OWN_GLOBALS))
    if mode == "walk":
        # the game's own base64 and zlib, for Shortest Path's packed terrain (Routing/PathGrid.lua): the base64 text is
        # kept as it is and decoded together with the inflate, so no binary string has to come back from Lua
        import base64, zlib
        L.execute("debugprofilestop = function() return os.clock() * 1000 end")
        L.execute("C_EncodingUtil = {}; Enum.CompressionMethod = { Zlib = 1 }")
        enc = L.globals().C_EncodingUtil
        enc.DecodeBase64 = lambda text: text
        enc.DecompressString = lambda text, method=None: zlib.decompress(base64.b64decode(text))
    if mode == "shadow":
        L.execute("""
            C_AddOns.GetAddOnInfo = function(name)
                if name == "OpenMap" then return "OpenMap", "OpenMap", "", true, nil end
                return nil
            end
            C_AddOns.GetAddOnEnableState = function(name) return name == "OpenMap" and 2 or 0 end
        """)
    load = L.eval("""function(src, chunk, addon, ns)
        local fn, err = loadstring(src, "@" .. chunk)
        if not fn then return false, err end
        local ok, e = xpcall(function() fn(addon, ns) end, function(m) return tostring(m) .. "\\n" .. debug.traceback() end)
        return ok, e
    end""")

    if mode == "standalone":
        addons = [("ForeverCore", os.path.join(SRC, "ForeverCore", "ForeverCore.toc")),
                  ("OpenMap", os.path.join(SRC, "OpenMap", "OpenMap.toc")),
                  ("ShortestPathForever", os.path.join(SRC, "ShortestPathForever", "ShortestPathForever.toc")),
                  ("Books_on_map_Forever", os.path.join(SRC, "Books_on_map_Forever", "Books_on_map_Forever.toc"))]
    else:
        addons = [("ForeverCore", os.path.join(BUILD, "ForeverCore", "ForeverCore.toc")),
                  ("BookFinder", os.path.join(BUILD, "BookFinder", "BookFinder.toc"))]

    load_errors, spaces = [], {}
    for name, toc in addons:
        ns = L.eval("{}")
        spaces[name] = ns
        base = os.path.dirname(toc)
        for rel in toc_entries(toc):
            path = os.path.join(base, rel)
            if not os.path.exists(path):
                load_errors.append(f"{name}: missing {rel}")
                continue
            ok, err = load(open(path, encoding="utf-8-sig").read(), f"{name}/{rel}", name, ns)
            if not ok:
                load_errors.append(f"LOAD {name}/{rel}: {err}")

    names = L.table_from([n for n, _ in addons])
    L.eval("""function(names)
        for i = 1, #names do FireEvent("ADDON_LOADED", names[i]) end
        FireEvent("VARIABLES_LOADED")
        FireEvent("PLAYER_LOGIN")
        FireEvent("PLAYER_ENTERING_WORLD", true, false)
        RunTimers(5)
        IN_COMBAT = true
        FireEvent("PLAYER_REGEN_DISABLED")
        RunTimers(2)
        IN_COMBAT = false
        FireEvent("PLAYER_REGEN_ENABLED")
        RunTimers(3)
        local commands = {
            OPENMAP = { "status", "news" },
            SHORTESTPATHFOREVER = { "stats", "perf" },
            BOOKSONMAP = { "help", "next", "route", "route print" },
            BOOKFINDER = { "status", "help" },
        }
        for key, list in pairs(commands) do
            local fn = SlashCmdList[key]
            if fn then
                for _, msg in ipairs(list) do
                    local ok, e = pcall(fn, msg)
                    if not ok then ERRORS[#ERRORS + 1] = "slash " .. key .. " " .. msg .. ": " .. tostring(e) end
                end
            end
        end
        RunTimers(3)
    end""")(names)

    if mode == "dump":
        return lua_to_py(L.eval(DUMP)())
    if mode == "walk":
        return lua_to_py(L.eval(WALK)(spaces["BookFinder"]))

    checks = []
    if mode != "standalone":
        root = spaces["BookFinder"]
        check = L.eval("""function(root, shadow)
            local out = {}
            local function want(cond, msg) if not cond then out[#out + 1] = msg end end
            for _, key in ipairs({ "OpenMap", "SPF", "Books" }) do want(type(root[key]) == "table", "no private table for " .. key) end
            want(root.OpenMap ~= root.SPF and root.SPF ~= root.Books, "components share a table")
            want(BookFinder and BookFinder.components, "no BookFinder global")
            want(root.SPF.db ~= nil and root.Books.db ~= nil, "SP or Books have no saved settings after login")
            want(root.Books.db ~= root.SPF.db, "SP and Books share settings")
            want(ShortestPathForever and ShortestPathForever.API, "Shortest Path's API isn't published")
            want(SlashCmdList.BOOKFINDER and SlashCmdList.BOOKSONMAP, "a slash command is missing")
            want(BookFinder_OnAddonCompartmentClick, "no compartment function")
            if shadow then
                want(root.OpenMap.__skip and not BookFinder.Active("OpenMap"), "OpenMap didn't stand aside for its standalone copy")
                want(OpenMap == nil and OpenMapAPI == nil, "BookFinder's OpenMap still loaded while standing aside")
                want(BookFinder.Active("SPF") and BookFinder.Active("Books"), "the other parts stood aside too")
            else
                want(OpenMap == root.OpenMap, "OpenMap's global isn't its own table")
                want(OpenMapAPI and OpenMapAPI.major == 1, "OpenMap's API isn't published")
                want(SlashCmdList.OPENMAP, "no /openmap")
                want(root.OpenMap.Media and root.OpenMap.Media.path:find("BookFinder\\\\OpenMap\\\\Media", 1, true), "OpenMap's media path isn't inside BookFinder")
            end
            return out
        end""")
        res = check(root, mode == "shadow")
        if mode == "merged":
            try:
                extra = L.eval(INTEGRATION)(root)
                extra = [extra[i] for i in range(1, len(extra) + 1)]
            except lupa.LuaError as e:
                extra = ["integration crashed: " + str(e)[:600]]
            res = list(res.values()) + extra
            res = L.table_from(res)
        checks = [res[i] for i in range(1, len(res) + 1)]

    errs = L.eval("ERRORS")
    runtime = [errs[i] for i in range(1, len(errs) + 1)]
    slash = L.eval("function() local t = {} for k in pairs(SlashCmdList) do t[#t + 1] = tostring(k) end return t end")()
    slash = {slash[i] for i in range(1, len(slash) + 1)}
    return load_errors, runtime, checks, slash


# Every page of the settings window, as the code builds it (mode "dump"): BookFinder's category from the recording
# Settings stub, and OpenMap's World map page from its own options table (AceConfig), names and values resolved
DUMP = r"""function()
    local function value(setting)
        if not setting then return nil end
        local ok, v = pcall(setting.GetValue, setting)
        if ok then return v end
        return setting.default
    end
    local function items(c)
        local list = {}
        for _, it in ipairs(c.items or {}) do
            local st = rawget(it, "setting")
            local e = { kind = rawget(it, "kind"), name = rawget(it, "name") or (st and rawget(st, "name")), tooltip = rawget(it, "tooltip"),
                button = rawget(it, "buttonText") }
            if st then e.value = value(st) e.default = rawget(st, "default") end
            local o = rawget(it, "options")
            if e.kind == "slider" and o then
                e.min, e.max, e.step = rawget(o, "min"), rawget(o, "max"), rawget(o, "step")
                local fmt = rawget(o, "fmt")
                if fmt and e.value ~= nil then local ok, t = pcall(fmt, e.value) if ok then e.valueText = tostring(t) end end
            elseif e.kind == "dropdown" and type(o) == "function" then
                local ok, data = pcall(o)
                if ok and type(data) == "table" then
                    e.choices = {}
                    for _, d in ipairs(data) do e.choices[#e.choices + 1] = { value = d.value, label = d.label } end
                end
            end
            list[#list + 1] = e
        end
        return list
    end
    local cat = SETTINGS.listed[1]
    local out = { root = { name = cat.name, items = items(cat) }, pages = {} }
    for _, sub in ipairs(cat.subs) do out.pages[#out.pages + 1] = { name = sub.name, items = items(sub) } end

    -- OpenMap's options table (the World map page draws it)
    local ACR = LibStub("AceConfigRegistry-3.0")
    local ok, opts = pcall(ACR.GetOptionsTable, ACR, "OpenMap", "dialog", "AceGUI-3.0")
    local function walk(node, path, inh, into)
        local args = {}
        for k, child in pairs(node.args or {}) do args[#args + 1] = { k = k, c = child } end
        table.sort(args, function(a, b)
            local oa, ob = tonumber(a.c.order) or 100, tonumber(b.c.order) or 100
            if oa ~= ob then return oa < ob end
            return tostring(a.k) < tostring(b.k)
        end)
        for _, a in ipairs(args) do
            local child, key = a.c, a.k
            local p = { unpack(path) } p[#p + 1] = key
            local ih = {}
            for kk, vv in pairs(inh) do ih[kk] = vv end
            for _, f in ipairs({ "get", "set", "disabled", "hidden", "handler" }) do if child[f] ~= nil then ih[f] = child[f] end end
            local info = { options = opts, option = child, type = child.type, handler = ih.handler, appName = "OpenMap" }
            for i, s in ipairs(p) do info[i] = s end
            local function resolve(v, ...) if type(v) == "function" then local okr, r = pcall(v, info, ...) return okr and r or nil end return v end
            local e = { key = key, type = child.type, name = resolve(child.name), desc = resolve(child.desc),
                hidden = resolve(ih.hidden) and true or false, disabled = resolve(ih.disabled) and true or false,
                min = child.min, max = child.max, step = child.step, isPercent = child.isPercent }
            if child.type ~= "group" and child.type ~= "header" and child.type ~= "description" and child.type ~= "execute" then
                e.value = resolve(ih.get)
                if type(e.value) == "table" then e.value = nil end
            end
            if child.type == "select" then
                local vals = resolve(child.values)
                if type(vals) == "table" then
                    e.choices = {}
                    for vk, vl in pairs(vals) do e.choices[#e.choices + 1] = { value = vk, label = vl } end
                    table.sort(e.choices, function(x, y) return tostring(x.value) < tostring(y.value) end)
                end
            end
            if child.type == "group" then e.items = {} walk(child, p, ih, e.items) end
            into[#into + 1] = e
        end
    end
    out.openmap = {}
    if ok and opts then walk(opts, {}, {}, out.openmap) end
    return out
end"""


# Shortest Path's own walking search on the walks a player saw drawn straight (and one as a control)
WALK = r"""function(root)
    local Path = root.SPF.Path
    local out = {}
    local walks = {
        { "control: Goldshire to Stormwind", 0, { map = 0, x = -9464, y = 62 }, { map = 0, x = -8840.6, y = 489.7 } },
        { "Powderfuse Port to Stormwind", 0, { map = 0, x = -8226.9, y = -5783.1, z = 6 }, { map = 0, x = -8840.6, y = 489.7 } },
        { "Gadgetzan to Steamwheedle Port", 1, { map = 1, x = -7177, y = -3785 }, { map = 1, x = -6929.4, y = -4931.3, z = 6 } },
        { "Freewind Post (lift bottom) to Blackfathom Deeps", 1, { map = 1, x = -5390.8, y = -2497.0, z = -40.4 }, { map = 1, x = 4249.1, y = 748.4 } },
    }
    for _, w in ipairs(walks) do
        local name, map, from, to = w[1], w[2], w[3], w[4]
        local r = { name = name, hasData = Path.HasData(map) }
        local t0 = os.clock()
        local ok, points, cost, expansions = pcall(Path.FindSync, map, from, to)
        r.ms = math.floor((os.clock() - t0) * 1000)
        r.expansions = expansions
        if not ok then
            r.error = tostring(points)
        elseif type(points) == "table" then
            local len, px, py = 0, from.x, from.y
            for _, p in ipairs(points) do
                len = len + math.sqrt((p.x - px) ^ 2 + (p.y - py) ^ 2)
                px, py = p.x, p.y
            end
            r.points, r.cost = #points, cost
            r.length = math.floor(len)
            r.straight = math.floor(math.sqrt((to.x - from.x) ^ 2 + (to.y - from.y) ^ 2))
        else
            r.reason = tostring(cost)
        end
        out[#out + 1] = r
    end
    return out
end"""


def lua_to_py(v):
    if lupa.lua_type(v) == "table":
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [lua_to_py(v[i]) for i in range(1, len(keys) + 1)]
        if not keys:
            return []
        return {str(k): lua_to_py(v[k]) for k in keys if lupa.lua_type(v[k]) != "function"}
    if lupa.lua_type(v) == "function":
        return None
    return v


def first_line(e):
    # the message without the chunk name's component prefix, so standalone and merged compare
    line = e.split("\n")[0]
    line = re.sub(r"\.\.\.[^/\s]*/", "", line)  # (Lua shortens long chunk names from the left)
    line = re.sub(r"@?(ForeverCore|OpenMap|ShortestPathForever|Books_on_map_Forever|BookFinder)/", "", line)
    line = re.sub(r"^(LOAD )(?:OpenMap|ShortestPathForever|Books_on_map_Forever|BookFinder)/", r"\1", line)
    line = re.sub(r":\d+:", ":N:", line)  # (line numbers move where the build rewrote a line)
    line = re.sub(r"0x[0-9a-f]+", "0x", line)
    return line


def report(mode, result):
    load_errors, runtime, checks, slash = result
    print(f"== {mode}: load errors {len(load_errors)}, runtime errors {len(runtime)}, failed checks {len(checks)}, "
          f"slash commands {len(slash)}")
    return load_errors, runtime, checks


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "diff"
    if mode == "walk":
        for r in run("walk"):
            print(r)
        sys.exit(0)
    if mode == "dump":
        import json
        out = sys.argv[2] if len(sys.argv) > 2 else "settings.json"
        with open(out, "w", encoding="utf-8") as f:
            json.dump(run("dump"), f, ensure_ascii=False, indent=1)
        print("wrote", out)
        sys.exit(0)
    if mode in ("standalone", "merged", "shadow"):
        le, rt, ck = report(mode, run(mode))[:3]
        for e in le + rt:
            print("ERROR:", e[:1200])
            print("-" * 60)
        for c in ck:
            print("CHECK FAILED:", c)
        sys.exit(1 if (le or rt or ck) else 0)

    result = run("standalone")
    base = report("standalone", result)
    known = {first_line(e) for e in base[0] + base[1]}
    base_slash = result[3]
    bad = 0
    for m in ("merged", "shadow"):
        result = run(m)
        le, rt, ck = report(m, result)[:3]
        missing = sorted(base_slash - result[3] - ({"OPENMAP"} if m == "shadow" else set()))
        if missing:
            ck = ck + ["slash commands the standalone addons have and this doesn't: " + ", ".join(missing)]
        new = []
        for e in le + rt:
            k = first_line(e)
            if k not in known and k not in {first_line(x) for x in new}:
                new.append(e)
        for e in new:
            print(f"NEW in {m}:", e[:1500])
            print("-" * 60)
        for c in ck:
            print(f"CHECK FAILED in {m}:", c)
        bad += len(new) + len(ck)
    print("PASS: the merged build adds no errors" if not bad else f"FAIL: {bad} problem(s) only the merged build has")
    sys.exit(1 if bad else 0)
