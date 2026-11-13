-- Books on map (Forever), in BookFinder: waypoints are the game's own map pin and tracking arrow
-- (BookFinder.Waypoint). Upstream sent them to Shortest Path Forever or TomTom; BookFinder has neither, so this file
-- keeps the names the rest of Books calls and answers them with the one pin. A route is guided one book at a time:
-- the pin is on its next book, and moves on as each one is collected (ns.SyncRouteWaypoints).
local ADDON, ns = ...; ns = ns.Books; if ns.__skip then return end
local L = ns.L

local guided, guidedLoc = false, nil   -- the route's stop the pin was put on

local function pin(loc, title)
  return BookFinder and BookFinder.Waypoint and BookFinder.Waypoint(loc[1], loc[2], loc[3], title) or false
end

-- No travel times: the tracker and the books tab show yards.
function ns.TravelSeconds() return nil end

function ns.WaypointProvider() return BookFinder and BookFinder.Waypoint and L["Map pin"] or nil end
function ns.RouteWaypointProvider() return ns.WaypointProvider() end

function ns.WaypointHint()
  if ns.WaypointProvider() then return L["Click: put a map pin on it"] end
end

-- one book location; true when the pin was set
function ns.Waypoint(loc, title)
  if not loc then return false end
  guided, guidedLoc = false, nil
  return pin(loc, title)
end

-- the route is guided while the game's pin is on the stop this file put it on
function ns.RouteGuided()
  if not guided then return false end
  local current = BookFinder and BookFinder.CurrentWaypoint and BookFinder.CurrentWaypoint()
  return current ~= nil and guidedLoc ~= nil and current.map == guidedLoc[1] and current.x == guidedLoc[2] and current.y == guidedLoc[3]
end

local function guide(route)
  local s = route[1]
  if not s then return false end
  if pin(s.loc, ("%d/%d %s"):format(1, #route, s.book.name)) then
    guided, guidedLoc = true, s.loc
    return true
  end
  return false
end

function ns.SendRouteWaypoints(route)
  if #route == 0 then print(ns.PREFIX .. L["Route finished!"]) return end
  guide(route)
  if ns.OnGuidanceChanged then ns.OnGuidanceChanged() end
end

function ns.CancelRouteWaypoints()
  if ns.RouteGuided() and BookFinder and BookFinder.ClearWaypoint then BookFinder.ClearWaypoint() end
  guided, guidedLoc = false, nil
end

-- the route changed (a book collected, skipped or the order rebuilt): the pin moves to its new first stop
function ns.SyncRouteWaypoints(route)
  if not ns.RouteGuided() then return end
  if #route == 0 then ns.CancelRouteWaypoints() return end
  guide(route)
end
