-- Books on map (Forever): alerts (book nearby, book found, reward goal reached), queued, top of
-- the screen. One card, tinted per kind: blue (nearby), green (found), gold (reward).
-- Icon pop + halo burst, a light sweep over the card, a countdown line that pauses on hover.
-- Left-click: options window, right-click: dismiss.
local _, ns = ...; ns = ns.Books; if ns.__skip then return end
local L = ns.L
local S = ns.Skin
local BOOKS = ns.BOOKS
local MEDIA = S.MEDIA

local W, H = 340, 84
local ICON = 46
local SHOW_TIME = { nearby = 5, found = 4.5, goal = 6 }
local KINDS = {
  nearby = S.C.gold,  -- the addon's blue
  found  = S.C.good,  -- green
  goal   = S.C.gold1, -- warm gold
}

local queue = {}
local toast, showNext

local function tint(tex, col, a) tex:SetVertexColor(col[1], col[2], col[3], a or 1) end

local function create()
  local f = CreateFrame("Button", "BooksOnMapForeverToast", UIParent)
  f:SetSize(W, H)
  f:SetPoint("TOP", 0, -150)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  S.Shadow(f, 14, 0.55)
  S.Rounded(f, 12)
  S.EdgeGlow(f, 48, 0.14)

  -- colored wash from the left, fading out toward the middle
  f.wash = f:CreateTexture(nil, "BACKGROUND", nil, -4)
  f.wash:SetPoint("TOPLEFT", 2, -2)
  f.wash:SetPoint("BOTTOMLEFT", 2, 2)
  f.wash:SetWidth(W * 0.6)

  -- accent stripe on the left edge
  f.stripe = f:CreateTexture(nil, "ARTWORK", nil, 2)
  f.stripe:SetPoint("TOPLEFT", 6, -16)
  f.stripe:SetPoint("BOTTOMLEFT", 6, 16)
  f.stripe:SetWidth(2)

  -- icon, with a soft halo behind it
  f.halo = f:CreateTexture(nil, "BORDER", nil, 2)
  f.halo:SetTexture(MEDIA .. "Glow")
  f.halo:SetBlendMode("ADD")
  f.halo:SetSize(96, 96)
  f.iconBox = S.Icon(f, ICON)
  f.iconBox:SetPoint("CENTER", f, "LEFT", 18 + ICON / 2, 0)
  f.halo:SetPoint("CENTER", f.iconBox)
  f.icon = f.iconBox.tex

  local x = 18 + ICON + 14
  local tw = W - x - 16
  f.kicker = S.Text(f, 11)
  f.kicker:SetPoint("TOPLEFT", x, -14)
  f.kicker:SetWidth(tw)
  f.kicker:SetWordWrap(false)

  f.title = S.Text(f, 15)
  f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -3)
  f.title:SetWidth(tw)
  f.title:SetWordWrap(false)

  f.sub = S.Text(f, 11, "muted")
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
  f.sub:SetWidth(tw)
  f.sub:SetWordWrap(false)

  -- progress (found / goal cards): thin bar + count on its right
  f.bar = S.ProgressBar(f, 5)
  f.bar:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
  f.bar:SetWidth(tw - 58)
  f.count = S.Text(f, 11, "muted")
  f.count:SetPoint("LEFT", f.bar, "RIGHT", 8, 0)

  -- countdown line along the bottom
  f.timer = f:CreateTexture(nil, "ARTWORK", nil, 3)
  f.timer:SetPoint("BOTTOMLEFT", 14, 5)
  f.timer:SetHeight(2)

  -- light sweep over the card when it appears
  local clip = CreateFrame("Frame", nil, f)
  clip:SetPoint("TOPLEFT", 2, -2)
  clip:SetPoint("BOTTOMRIGHT", -2, 2)
  f.canSweep = clip.SetClipsChildren and pcall(clip.SetClipsChildren, clip, true)
  f.shine = clip:CreateTexture(nil, "OVERLAY")
  f.shine:SetTexture(MEDIA .. "Shine")
  f.shine:SetBlendMode("ADD")
  f.shine:SetSize(90, H)
  f.shine:Hide()

  f:SetScript("OnEnter", function(self)
    self.hover = true
    self:SetBorderColor(S.Color(self.col))
  end)
  f:SetScript("OnLeave", function(self)
    self.hover = nil
    self:SetBorderColor(self.col[1], self.col[2], self.col[3], 0.55)
  end)
  f:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then ns.ToggleOptions() end
    self.left = 0 -- either way the card goes away
  end)

  -- idle animation: halo breathing, countdown, light sweep
  f:SetScript("OnUpdate", function(self, elapsed)
    self.clock = self.clock + elapsed
    self.halo:SetAlpha(0.45 + 0.25 * math.sin(self.clock * 3))
    if self.canSweep then
      local t = self.clock - 0.25
      if t > 0 and t < 0.9 then
        self.shine:Show()
        self.shine:SetPoint("LEFT", self, "LEFT", -90 + (W + 180) * (t / 0.9), 0)
      else
        self.shine:Hide()
      end
    end
    if self.closing then return end
    if not self.hover then self.left = self.left - elapsed end
    self.timer:SetWidth(math.max(0.01, (W - 28) * math.max(0, self.left) / self.total))
    if self.left <= 0 then
      self.closing = true
      S.AnimateClose(self, 0, 12)
      C_Timer.After(0.25, showNext)
    end
  end)
  f:Hide()
  return f
end

local function play(t)
  local f = toast
  local col = KINDS[t.kind]
  f.col = col
  f.icon:SetTexture(t.icon)
  f.kicker:SetText(t.kicker)
  f.kicker:SetTextColor(S.Color(col))
  f.title:SetText(t.title)

  S.Gradient(f.wash, { col[1], col[2], col[3], 0.16 }, { col[1], col[2], col[3], 0 }, true)
  f.stripe:SetColorTexture(col[1], col[2], col[3], 0.9)
  f.timer:SetColorTexture(col[1], col[2], col[3], 0.6)
  tint(f.halo, col, 1)
  tint(f.shine, col, 0.35)
  f:SetBorderColor(col[1], col[2], col[3], 0.55)
  for _, r in ipairs({ f.shadow:GetRegions() }) do r:SetVertexColor(col[1] * 0.4, col[2] * 0.4, col[3] * 0.4, 0.6) end
  f.iconBox:SetBorderColor(S.Color(col))

  local withBar = t.kind ~= "nearby"
  f.sub:SetShown(not withBar)
  f.bar:SetShown(withBar)
  f.count:SetShown(withBar)
  if withBar then
    local done = ns.CountDone()
    f.count:SetText(("%d / %d"):format(done, #BOOKS))
    f.bar:SetMinMaxValues(0, #BOOKS)
    f.bar:SetValue(math.max(0, done - 1))
  else
    f.sub:SetText(t.text)
  end

  f.total = SHOW_TIME[t.kind]
  f.left, f.clock, f.closing = f.total, 0, nil
  f:Show()
  S.AnimateOpen(f, 0, 14)

  -- icon pop + halo burst
  S.Tween(f.iconBox, { dur = 0.45, from = 0.55, to = 1, ease = "outBack",
    set = function(v) f.iconBox:SetSize(ICON * v, ICON * v) end })
  local burst = t.kind == "goal" and 170 or 130
  S.Tween(f.halo, { dur = 0.6, from = burst, to = 96, ease = "outCubic",
    set = function(v) f.halo:SetSize(v, v) end })
  -- the bar fills the last step once the card is in place
  if withBar then C_Timer.After(0.3, function() if f:IsShown() then f.bar:SetValue(ns.CountDone()) end end) end

  if t.sound and SOUNDKIT then pcall(PlaySound, t.sound) end
end

showNext = function()
  local t = table.remove(queue, 1)
  if t then play(t) else toast.busy = nil end
end

-- kind: "nearby" | "found" | "goal"; text: the line under the title (nearby only)
function ns.ShowToast(kind, icon, kicker, title, text, sound)
  queue[#queue + 1] = { kind = kind, icon = icon, kicker = kicker, title = title, text = text, sound = sound }
  toast = toast or create()
  if not toast.busy then
    toast.busy = true
    showNext()
  end
end

local function bookIcon(b) return b.icon and ("Interface\\Icons\\" .. b.icon) or ns.ICON end
ns.BookIcon = bookIcon

-- reward goal reached: the sound plays right away, its card follows the "book found" one
function ns.NotifyGoal(goal)
  PlaySoundFile(ns.COMPLETION_SOUND, "Master")
  ns.ShowToast("goal", ns.ADDON_ICON, L["%d books: hand them in at the library!"]:format(goal),
    L[ns.GOAL_LABELS[goal]])
end

-- called by ns.SetDone for a book found (not for silent changes)
function ns.NotifyCollected(b)
  if ns.db.noToasts then return end
  local done = ns.CountDone()
  ns.ShowToast("found", bookIcon(b), L["Book found!"], b.name)
  for _, goal in ipairs(ns.GOALS) do
    if done == goal then ns.NotifyGoal(goal) end
  end
end
