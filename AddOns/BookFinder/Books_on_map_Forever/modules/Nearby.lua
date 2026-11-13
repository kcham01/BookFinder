-- Books on map (Forever): nearby detector (an alert with a sonar ping when a missing book is close)
local _, ns = ...; ns = ns.Books; if ns.__skip then return end
local L = ns.L
local BOOKS = ns.BOOKS

local RADIUS = 50 -- yards: alert inside this distance
local REARM = 100 -- yards: the same book can alert again once the player went this far
local CHECK_EVERY = 1 -- seconds

local alerted = {} -- book -> true while the player hasn't left its area

-- distance (yards) and location of the book's closest place on the player's continent
local function closest(b, cont, px, py)
  local best, bestLoc
  for _, loc in ipairs(b.locs) do
    local w = ns.LocWorld(loc)
    if w and w.cont == cont then
      local d = math.sqrt((w.x - px) ^ 2 + (w.y - py) ^ 2)
      if not best or d < best then best, bestLoc = d, loc end
    end
  end
  return best, bestLoc
end

local function alert(b, loc, dist)
  local distText = L["%d yd"]:format(math.floor(dist))
  print(ns.PREFIX .. L["book nearby: %s - %s (%.1f, %.1f), %s"]:format(b.name, loc[4], loc[2], loc[3], distText))
  ns.ShowToast("nearby", ns.BookIcon(b), ("%s  |cff7f90ab%s|r"):format(L["Book nearby!"], distText), b.name,
    ("%s  |cff5cc8ff(%.1f, %.1f)|r"):format(loc[4], loc[2], loc[3]), SOUNDKIT and SOUNDKIT.MAP_PING)
end

local function check()
  if ns.db.noNearby then return end
  local cont, px, py = ns.PlayerWorldPos()
  if not cont then return end -- no position (e.g. inside an instance)
  for _, b in ipairs(BOOKS) do
    if not ns.IsDone(b) then
      local d, loc = closest(b, cont, px, py)
      if d and d <= RADIUS then
        if not alerted[b] then
          alerted[b] = true
          -- last check: a book held in the bags or the bank isn't missing
          if ns.OwnsBook(b) then ns.SetDone(b, true, true) else alert(b, loc, d) end
        end
      elseif alerted[b] and (not d or d > REARM) then
        alerted[b] = nil
      end
    end
  end
end

-- /bom test: plays the three alerts (nearby, book found, reward goal)
function ns.TestAlerts()
  local b = BOOKS[1]
  alert(b, b.locs[1], 32)
  ns.ShowToast("found", ns.BookIcon(b), L["Book found!"], b.name)
  ns.NotifyGoal(ns.GOALS[1])
end

function ns.InitNearby()
  C_Timer.NewTicker(CHECK_EVERY, check)
end
