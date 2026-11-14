"""Differential load test: the three addons standalone vs. merged into BookFinder, in one stubbed client.

Usage:  python3 tools/offline-test/merged.py [standalone|merged|shadow|diff]   (default: diff)
Needs:  pip install lupa; python3 tools/build.py --no-textures first (it reads build/)

Each mode loads the addons, fires ADDON_LOADED / PLAYER_LOGIN / PLAYER_ENTERING_WORLD,
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
    "OpenMapDB", "OpenMapCharDB", "BooksOnMapForeverGlobal", "BooksOnMapForeverDB",
    "BookFinder", "BookFinderDB", "OpenMapAPI", "OpenMap", "TomTom", "Questie", "QuestieLoader", "RXPCData",
    "Guidelime", "RXP", "Zygor", "ZGV", "WorldMapFrame_OnShow", "TrackedQuestsScrollFrame",
    "ChatThrottleLib", "LibQuestieDB", "QuestieConfig", "QuestieConfigCharacter", "QuestieProfilerEnabled", "QuestieCompat", "QuestieDB",
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

    -- "Take me there" is the game's own map pin: Books' single book and its route go to it, one stop at a time
    local pins = {}
    local canSet, setWP, track, clearWP, hasWP = C_Map.CanSetUserWaypointOnMap, C_Map.SetUserWaypoint, C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint, C_Map.ClearUserWaypoint, C_Map.HasUserWaypoint
    local savedPoint = UiMapPoint
    UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, position = { x = x, y = y } } end }
    C_Map.CanSetUserWaypointOnMap = function(map) return map ~= 9999 end
    C_Map.SetUserWaypoint = function(p) pins[#pins + 1] = p end
    C_Map.HasUserWaypoint = function() return #pins > 0 end
    C_Map.ClearUserWaypoint = function() wipe(pins) end
    C_SuperTrack = C_SuperTrack or {}
    local tracked = false
    C_SuperTrack.SetSuperTrackedUserWaypoint = function(on) tracked = on end
    want(BookFinder.Waypoint(1454, 50, 40, "Orgrimmar") and pins[1] and pins[1].uiMapID == 1454 and pins[1].position.y == 0.4 and tracked,
        "a map pin didn't go on the spot, tracked")
    want(BookFinder.Waypoint(9999, 50, 50, "Inside") == false, "a map that can't take a pin wasn't refused")
    want(BookFinder.Waypoint(nil, nil, nil, "Nowhere") == false, "a place with no spot wasn't refused")
    wipe(pins)
    local b1, b2 = B.BOOKS[1], B.BOOKS[2]
    want(B.Waypoint(b1.locs[1], b1.name) and pins[1].uiMapID == b1.locs[1][1], "Books' waypoint didn't put the map pin on the book")
    B.SendRouteWaypoints({ { book = b1, loc = b1.locs[1] }, { book = b2, loc = b2.locs[1] } })
    want(B.RouteGuided() and pins[#pins].uiMapID == b1.locs[1][1], "the route's first book didn't get the pin")
    B.SyncRouteWaypoints({ { book = b2, loc = b2.locs[1] } })
    want(B.RouteGuided() and pins[#pins].uiMapID == b2.locs[1][1], "the pin didn't move on to the route's next book")
    B.CancelRouteWaypoints()
    want(not B.RouteGuided() and #pins == 0, "cancelling the route left its pin")
    want(B.TravelSeconds(b1.locs[1]) == nil, "Books still asks for a travel time")
    C_Map.CanSetUserWaypointOnMap, C_Map.SetUserWaypoint, C_Map.ClearUserWaypoint, C_Map.HasUserWaypoint = canSet, setWP, clearWP, hasWP
    C_SuperTrack.SetSuperTrackedUserWaypoint = track
    UiMapPoint = savedPoint

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
    wm:Hide()   -- (the stand-in map is only enough for Books' pins)

    -- One menu for what the map shows: OpenMap's own panel, with Questie's icons and the books in it; nothing is added
    -- to the game's Show menu any more
    local wmod = root.OpenMap.modules and root.OpenMap.modules.worldmap
    want(BookFinder.MapMenuSections == nil, "BookFinder still adds switches to the game's Show menu")
    local okRows, panelRows = pcall(wmod.PanelRows)
    local ids = {}
    for _, r in ipairs(okRows and panelRows or {}) do if r.id then ids[r.id] = r end end
    for _, id in ipairs({ "icons", "group", "friends", "guild", "sketchShown", "questie", "boats", "flight" }) do
        want(ids[id], "OpenMap's panel has no " .. id .. " switch: " .. tostring(okRows and "" or panelRows))
    end
    local booksRows = 0
    for id in pairs(ids) do if id:match("^ext%.BookFinder%.") or id:match("^ext%.Books") then booksRows = booksRows + 1 end end
    want(booksRows >= 1, "OpenMap's panel has no Books switches")
    local r = ids.icons
    if r then local was = r[2]() and true or false r[3](not was) want((wmod.db.icons and true or false) == not was, "the dungeons switch didn't change OpenMap's setting") r[3](was) end
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
    local count = 0
    for _ in pairs(pages) do count = count + 1 end
    want(not pages["Journeys"] and not pages["Map icons"] and not pages["Interface"], "settings: Shortest Path's pages are still there")
    want(count <= 4, "settings: BookFinder's window has " .. count .. " pages (expected at most 4)")
    for _, page in ipairs({ "World map", "Library books" }) do
        want(pages[page], "settings: no " .. page .. " page in BookFinder's window")
    end
    want(BookFinder.OpenSettings("map") and BookFinder.OpenSettings("books") and BookFinder.OpenSettings(), "settings: a page can't be opened")

    -- Our dropdowns are drawn with Questie's dropdown library, from the same builder calls the game's menu takes
    local MT = BookFinder.MenuTest
    want(MT and BookFinder.ContextMenu, "the menu helper isn't there")
    if MT then
        local m, list = MT.NewList()
        local on = false
        m:CreateTitle("BookFinder")
        m:CreateButton("Settings", function() end)
        m:CreateDivider()
        m:CreateCheckbox("Route", function() return on end, function() on = not on end)
        local sub = m:CreateSubmenu("More")
        sub:CreateButton("Inside", function() end)
        want(#list == 5 and list[1].isTitle and list[3] == MT.Divider and list[5].hasArrow and #list[5].menuList == 1,
            "the menu builder didn't make Questie-style entries (" .. #list .. ")")
        list[4].func()
        want(on and list[4].checked() == true, "a menu checkbox didn't toggle or read back")
        local okOpen, errOpen = pcall(BookFinder.ContextMenu, UIParent, function(_, menu) menu:CreateTitle("x") end)
        want(okOpen, "opening a menu failed: " .. tostring(errOpen))
    end

    -- One minimap button and one launcher
    local LDBI = LibStub("LibDBIcon-1.0", true)
    local buttons = {}
    for name in pairs(LDBI and LDBI.objects or {}) do buttons[#buttons + 1] = name end
    want(#buttons == 1 and buttons[1] == "BookFinder", "minimap buttons: " .. table.concat(buttons, ", "))
    want(not rawget(_G, "OpenMapMinimapButton"), "another part made its own minimap button")
    local LDB = LibStub("LibDataBroker-1.1", true)
    local launchers = {}
    for name in LDB:DataObjectIterator() do launchers[#launchers + 1] = name end
    want(#launchers == 1 and launchers[1] == "BookFinder", "broker launchers: " .. table.concat(launchers, ", "))

    -- OpenMap draws its own docks, flight masters and townsfolk again (Shortest Path drew them before 2.0)
    local wm = root.OpenMap.modules and root.OpenMap.modules.worldmap
    want(wm and wm.db and wm.db.boats ~= false and wm.db.flight ~= false, "OpenMap's docks or flight masters are still off")
    local kinds = {}
    for _, k in ipairs(wm and wm.TOWNSFOLK or {}) do kinds[k.key] = true end
    want(kinds.vendor and kinds.innkeeper and kinds.mailbox and kinds.spirit and kinds.rare, "OpenMap lost some of its townsfolk")
    want(rawget(_G, "ShortestPathForever") == nil and rawget(_G, "ForeverCore") == nil, "Shortest Path or ForeverCore is still loaded")

    -- One search: the panel's box finds books, places and Questie's quests, NPCs and items
    local ST = BookFinder.SearchTest
    want(ST and BookFinder.DrawSearch, "the search can't draw")
    if ST then
        local function has(sections, key, test)
            for _, s in ipairs(sections) do
                if s.key == key then
                    for _, r in ipairs(s.rows) do if not test or test(r) then return true end end
                end
            end
            return false
        end
        local children = C_Map.GetMapChildrenInfo
        C_Map.GetMapChildrenInfo = function(id) if id == 1415 then return { { mapID = 1429, name = "Elwynn Forest" } } end return {} end
        want(has(ST.Run("goaz"), "books"), "search: a library book isn't found")
        want(has(ST.Run("elwynn"), "places"), "search: a zone isn't found")
        C_Map.GetMapChildrenInfo = children
        want(ST.ReadNow(), "search: Questie's database index never finished")
        local QDB = QuestieLoader:ImportModule("QuestieDB")
        local qname = QDB.QueryQuestSingle(9, "name")
        local found = qname and ST.Run(qname:lower())
        want(found and has(found, "quest", function(r) return r.key == "quest:9" end),
            "search: quest 9 (" .. tostring(qname) .. ") isn't found by its name; " .. tostring(ST.Index.lastError))
        local nname = QDB.QueryNPCSingle(6491, "name")
        want(nname and has(ST.Run(nname:lower()), "npc", function(r) return r.label == nname end),
            "search: NPC 6491 (" .. tostring(nname) .. ") isn't found by its name")
        local holder = CreateFrame("Frame")
        local okDraw, bottom, drawn = pcall(BookFinder.DrawSearch, holder, 0, "goaz")
        want(okDraw and type(bottom) == "number" and bottom > 0 and (drawn or 0) >= 1,
            "search: drawing the results failed: " .. tostring(bottom))
        local okClear, b2, n2 = pcall(BookFinder.DrawSearch, holder, 0, "")
        want(okClear and b2 == 0 and n2 == 0, "search: clearing it left rows behind")
    end

    -- The quest list in the map: Questie's tracker moves into the Quests tab, and the scrollbar beside it is its own
    -- (Questie scrolls by the wheel and hid its bar, while the game's list bar stayed showing and never moved)
    local QL = BookFinder.QuestLog
    want(QL, "the quest log module isn't there")
    if QL then
        QuestMapFrame.QuestsFrame = QuestMapFrame.QuestsFrame or CreateFrame("Frame", nil, QuestMapFrame)
        local list = rawget(_G, "Questie_BaseFrame") or CreateFrame("Frame", "Questie_BaseFrame", UIParent)
        local scroll = rawget(_G, "TrackedQuestsScrollFrame") or CreateFrame("ScrollFrame", "TrackedQuestsScrollFrame", list)
        scroll.ScrollBar = scroll.ScrollBar or CreateFrame("Slider", nil, scroll)
        local range = 200
        scroll.GetVerticalScrollRange = function() return range end
        scroll.ScrollBar:Hide()
        local holder = QL.Build()
        want(holder, "the Quests tab holder wasn't built")
        want(QL.Dock(), "Questie's tracker wasn't moved into the Quests tab")
        want(list:GetParent() == holder, "Questie's tracker isn't in the Quests tab")
        local p = Questie.db and Questie.db.profile
        if p then want(p.trackerLocked and p.sizerHidden, "Questie's tracker can still be dragged or sized in the map") end
        QL.Refresh()
        want(scroll.ScrollBar:IsShown(), "a list longer than the room shows no scrollbar of its own")
        range = 0
        QL.Refresh()
        want(not scroll.ScrollBar:IsShown(), "a list that fits still shows a scrollbar")
    end

    -- The in-game self-test runs from start to end and writes its record (the stub's map can't pass every check)
    -- (its waits are driven here, one after another: running the stub's clock that far would fire every other
    -- part's timers into pieces the stub lacks)
    local queued, after = {}, C_Timer.After
    C_Timer.After = function(_, fn) queued[#queued + 1] = fn end
    local okSelf, errSelf = pcall(BookFinder.SelfTest)
    want(okSelf, "the self-test didn't start: " .. tostring(errSelf))
    for _ = 1, 5000 do
        local fn = table.remove(queued, 1)
        if not fn then break end
        local okStep, errStep = pcall(fn)
        if not okStep then ERRORS[#ERRORS + 1] = "self-test step: " .. tostring(errStep) end
    end
    C_Timer.After = after
    local st = BookFinderDB.selftest
    want(st and st.finished and not st.crashed and #st.checks >= 25,
        "the self-test didn't finish its run: " .. tostring(st and (st.crashed or (#st.checks .. " checks"))))
    BookFinderDB.selftest = nil

    -- The recorder: BookFinder's errors, deduplicated
    BookFinder.RecordError("Interface/AddOns/BookFinder/Merge/Search.lua:1: boom")
    BookFinder.RecordError("Interface/AddOns/BookFinder/Merge/Search.lua:1: boom")
    BookFinder.RecordError("Interface/AddOns/OtherAddon/x.lua:1: not ours")
    local errs = BookFinderDB.errors or {}
    want(#errs == 1 and errs[1].count == 2, "the recorder didn't keep BookFinder's error once, counted (" .. #errs .. ")")
    BookFinderDB.errors = nil

    -- /bookfinder inspect records what the client has, without errors
    local okInspect, inspected = pcall(BookFinder.Inspect)
    want(okInspect and inspected and BookFinderDB.inspect and BookFinderDB.inspect.atlases and BookFinderDB.inspect.frames,
        "/bookfinder inspect failed: " .. tostring(inspected))

    -- The library books tab in the quest log: built, every book drawn with its distance, the nearest book, the one
    -- search, a click puts the map pin on it, Shift-click marks it, the route's rows, and /bom opens it
    local tabAPI = BookFinder.BooksTab
    want(tabAPI and BookFinder.OpenBooks and BookFinder.OpenQuestLog, "the books tab isn't there")
    if tabAPI then
        tabAPI.Attach()
        want(rawget(_G, "BookFinderBooksPanel") and rawget(_G, "BookFinderBooksTab"), "the books tab or its panel wasn't built")
        -- (where you stand, and a world for the books: OpenMap's stand-in from above puts each map's x beside the next)
        C_Map.GetBestMapForUnit = function() return 1429 end
        C_Map.GetPlayerMapPosition = function() return { x = 0.5, y = 0.5, GetXY = function(self) return self.x, self.y end } end
        local function gap(loc) return math.sqrt((1429.5 - (loc[1] + loc[2] / 100)) ^ 2 + (0.5 - loc[3] / 100) ^ 2) end
        local waypoint, sent = BookFinder.Waypoint, nil
        BookFinder.Waypoint = function(map, x, y, title) sent = title return true end
        tabAPI.Shown(true)
        local missing, quickest, quickestD = 0, nil, nil
        for _, b in ipairs(B.BOOKS) do
            if not B.IsDone(b) then
                missing = missing + 1
                for _, loc in ipairs(b.locs) do
                    local d = gap(loc)
                    if not quickestD or d < quickestD then quickest, quickestD = b, d end
                end
            end
        end
        want(tabAPI.Rows() >= #B.BOOKS + 2, "books tab: drew " .. tabAPI.Rows() .. " rows for " .. #B.BOOKS .. " books")
        for _ = 1, 500 do if not tabAPI.Step() then break end end
        want(tabAPI.Estimates() == missing, "books tab: " .. tabAPI.Estimates() .. " distances for " .. missing .. " missing books")
        local near = tabAPI.Spec("nearest")
        want(near and near.book == quickest, "books tab: the nearest book isn't the nearest ("
            .. tostring(near and near.book and near.book.name) .. " vs " .. tostring(quickest and quickest.name) .. ")")
        tabAPI.Search("Goaz")
        want(tabAPI.Rows() >= 1, "books tab: a search for a book drew nothing")
        tabAPI.Search("orgrimmar")
        want(tabAPI.Rows() >= 1, "books tab: the one search found no place called Orgrimmar")
        tabAPI.Search("")
        want(tabAPI.Rows() >= #B.BOOKS, "books tab: clearing the search didn't bring the books back")
        local spec = tabAPI.Spec(quickest.key)
        if spec then spec.onClick("LeftButton") end
        want(sent == quickest.name, "books tab: clicking a book didn't put the map pin on it")
        local shift = IsShiftKeyDown
        IsShiftKeyDown = function() return true end
        spec = tabAPI.Spec(quickest.key)
        if spec then spec.onClick("LeftButton") end
        want(B.IsDone(quickest), "books tab: Shift-click didn't mark the book collected")
        B.SetDone(quickest, false, true)
        IsShiftKeyDown = shift
        B.ToggleRoute(true)
        tabAPI.Refresh()
        want(tabAPI.Spec("route") and not tabAPI.Spec("start"), "books tab: the route under way has no row")
        B.ToggleRoute(false)
        tabAPI.Refresh()
        want(tabAPI.Spec("start") and not tabAPI.Spec("route"), "books tab: no row starts the route")
        tabAPI.Shown(false)
        BookFinder.Tabs.ShowQuests()
        -- (the files left out of the build: Books still calls their entry points)
        local okRetired, errRetired = pcall(function()
            SlashCmdList.BOOKSONMAP("welcome")
            B.Refresh()
            B.RefreshGroupPanel()
            B.InitMinimapButton()
        end)
        want(okRetired, "a left-out Books file is still needed: " .. tostring(errRetired))
        BookFinder.Tabs.ShowQuests()
        SlashCmdList.BOOKSONMAP("")
        want(BookFinder.Tabs.Selected() == "bookfinder.books" and not rawget(_G, "BooksOnMapForeverOptions"),
            "/bom doesn't open the books tab (or still builds Books' old window)")
        BookFinder.Tabs.ShowQuests()
        BookFinder.Waypoint = waypoint
    end

    for k, f in pairs(saved) do C_Map[k] = f end
    CreateVector2D = savedVector
    return out
end"""


def toc_meta(toc_path):
    meta = {}
    with open(toc_path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("## "):
                k, sep, v = line[3:].partition(":")
                if sep:
                    meta[k.strip()] = v.strip()
    return meta


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
    # the game's base64, zlib and CBOR, in Lua (QuestieDB's database, Shortest Path's terrain). zlib is LibDeflate's,
    # loaded first as the game's own function is there before any addon
    L.execute(open(os.path.join(HERE, "encoding.lua"), encoding="utf-8").read())
    for lib in ("LibStub/LibStub.lua", "LibDeflate/LibDeflate.lua"):
        L.execute(open(os.path.join(SRC, "Questie", "Libs", lib), encoding="utf-8").read())
    # (more of the game's API Questie's libraries need)
    L.execute("""
        UnitNameUnmodified = UnitName
        GetAppropriateTooltip = function() return GameTooltip end
        local function pool()
            return setmetatable({}, { __index = function(_, k) if type(k) ~= "number" then return function() return nil end end end })
        end
        CreateFramePool = function() return pool() end
        CreateUnsecuredRegionPoolInstance = function() return pool() end
    """)
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
        addons = [("QuestieDB", os.path.join(SRC, "QuestieDB", "QuestieDB_Forever.toc")),
                  ("Questie", os.path.join(SRC, "Questie", "Questie_Forever.toc")),
                  ("OpenMap", os.path.join(SRC, "OpenMap", "OpenMap.toc")),
                  ("Books_on_map_Forever", os.path.join(SRC, "Books_on_map_Forever", "Books_on_map_Forever.toc"))]
    else:
        addons = [("BookFinder", os.path.join(BUILD, "BookFinder", "BookFinder.toc"))]

    # each addon's toc fields (QuestieDB's database is its toc's), and what has loaded, as the game answers them
    metadata = {name: toc_meta(toc) for name, toc in addons}
    loaded = set()
    get_meta = lambda name, key: metadata.get(name, {}).get(key)
    is_loaded = lambda name: name in loaded
    L.globals().C_AddOns.GetAddOnMetadata = get_meta
    L.globals().GetAddOnMetadata = get_meta
    L.globals().C_AddOns.IsAddOnLoaded = is_loaded
    L.globals().IsAddOnLoaded = is_loaded

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
        loaded.add(name)

    names = L.table_from([n for n, _ in addons])
    L.eval("""function(names)
        for i = 1, #names do FireEvent("ADDON_LOADED", names[i]) end
        FireEvent("VARIABLES_LOADED")
        FireEvent("PLAYER_LOGIN")
        FireEvent("PLAYER_ENTERING_WORLD", true, false)
        RunTimers(20)   -- (past BookFinder's 15 s fallback for listing its settings window, as Questie can't start here)
        IN_COMBAT = true
        FireEvent("PLAYER_REGEN_DISABLED")
        RunTimers(2)
        IN_COMBAT = false
        FireEvent("PLAYER_REGEN_ENABLED")
        RunTimers(3)
        local commands = {
            OPENMAP = { "status", "news" },
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

    checks = []
    if mode != "standalone":
        root = spaces["BookFinder"]
        check = L.eval("""function(root, shadow)
            local out = {}
            local function want(cond, msg) if not cond then out[#out + 1] = msg end end
            for _, key in ipairs({ "OpenMap", "Books", "Questie" }) do want(type(root[key]) == "table", "no private table for " .. key) end
            want(root.OpenMap ~= root.Books and root.Books ~= root.Questie, "components share a table")
            want(BookFinder and BookFinder.components, "no BookFinder global")
            want(root.Books.db ~= nil, "Books has no saved settings after login")
            want(SlashCmdList.BOOKFINDER and SlashCmdList.BOOKSONMAP, "a slash command is missing")
            want(BookFinder_OnAddonCompartmentClick, "no compartment function")
            -- Questie and its database, inside BookFinder: the database read from BookFinder's toc, Questie not refusing
            -- to run under another folder's name
            if not shadow then
                want(type(LibQuestieDB) == "table" and LibQuestieDB.Quest and LibQuestieDB.Quest.Get, "QuestieDB isn't loaded")
                local okQ, name = pcall(function() return LibQuestieDB.Quest.Get(9, "name") end)
                want(okQ and type(name) == "string" and name ~= "", "QuestieDB can't read a quest from BookFinder's toc: " .. tostring(name))
                local okN, npc = pcall(function() return LibQuestieDB.Npc.Get(6491, "name") end)
                want(okN and type(npc) == "string" and npc ~= "", "QuestieDB can't read an NPC: " .. tostring(npc))
                want(QuestieLoader ~= nil and Questie ~= nil, "Questie isn't loaded")
                want(not (StaticPopupDialogs and StaticPopupDialogs.QUESTIE_ADDON_NAME_ERROR), "Questie refused to run inside BookFinder")
                want(BookFinder.Loaded("Questie") and BookFinder.Loaded("QuestieDB"), "BookFinder doesn't report Questie as loaded")
            else
                -- (only OpenMap's standalone copy runs here: Questie stays BookFinder's)
                want(not BookFinder.Skip("Questie") and type(LibQuestieDB) == "table", "Questie stood aside for OpenMap's standalone copy")
            end
            if shadow then
                want(root.OpenMap.__skip and not BookFinder.Active("OpenMap"), "OpenMap didn't stand aside for its standalone copy")
                want(OpenMap == nil and OpenMapAPI == nil, "BookFinder's OpenMap still loaded while standing aside")
                want(BookFinder.Active("Books"), "the other parts stood aside too")
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
    line = re.sub(r"@?(ForeverCore|QuestieDB|Questie|OpenMap|ShortestPathForever|Books_on_map_Forever|BookFinder)/", "", line)
    line = re.sub(r"^(LOAD )(?:QuestieDB|Questie|OpenMap|ShortestPathForever|Books_on_map_Forever|BookFinder)/", r"\1", line)
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
