-- Books on map (Forever): rewards tab on the right of the options window
-- Sources: https://foreverchanges.pro/library-books, https://www.warcrafttavern.com/forever/guides/library-books/
local _, ns = ...; ns = ns.Books; if ns.__skip then return end
local L = ns.L
local S = ns.Skin

local PANEL_W = 260
local TIER_H, ITEM_H = 22, 36

-- items: { itemID, English name } (translated by Locales\*.lua: the cached item name is in the client's language)
local TIERS = {
  { goal = 10, label = "10 books: necklace", items = {
    { 277203, "Scholarly Pendant" },
    { 277204, "Erudite's Amulet" },
  } },
  { goal = 20, label = "20 books: ring", items = {
    { 281634, "Field Researcher's Loop" },
    { 281635, "Philanthropist's Ring" },
  } },
  { goal = 25, label = "25 books: bow, crest or light", items = {
    { 277254, "Truthseeker's Bow" },
    { 277258, "Crest of Elucidation" },
    { 277260, "Researcher's Night Light" },
  } },
}
ns.REWARD_TIERS = TIERS -- (BookFinder: its books tab lists the same tiers)

-- item API: global in older clients, under C_Item in newer ones
local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local getIcon = C_Item and C_Item.GetItemIconByID or GetItemIcon
local getQualityColor = C_Item and C_Item.GetItemQualityColor or GetItemQualityColor
local panel

-- name, quality color, icon and slot from the item cache
local function fillItem(row)
  local _, _, quality, _, _, _, subType, _, equipLoc, icon, _, classID, subclassID = getInfo(row.id)
  row.icon:SetTexture(icon or getIcon(row.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
  row.name:SetText(L[row.fallback])
  if quality then
    local r, g, b = getQualityColor(quality)
    row.name:SetTextColor(r, g, b)
  end
  -- slot and type come in the client's language: the chosen language's ones from the locale
  local slot = equipLoc and (ns.Localized(equipLoc) or _G[equipLoc])
  if equipLoc then
    subType = ns.Localized(("ITEM_SUBCLASS_%s_%s"):format(classID, subclassID)) or subType
  end
  if slot and slot ~= "" then
    row.slot:SetText(subclassID and subclassID ~= 0 and subType and ("%s - %s"):format(slot, subType) or slot)
  else
    row.slot:SetText("")
  end
end

function ns.RefreshRewards()
  if not panel or not panel:IsShown() then return end
  local done = ns.CountDone()
  for _, h in ipairs(panel.tiers) do
    local reached = done >= h.goal
    h.label:SetTextColor(S.Color(reached and S.C.good or S.C.accent))
    h.count:SetTextColor(S.Color(reached and S.C.good or S.C.muted))
    h.count:SetText(("%d / %d"):format(math.min(done, h.goal), h.goal))
  end
  for _, row in ipairs(panel.items) do fillItem(row) end
end

local function createTier(parent, tier, y)
  local h = CreateFrame("Frame", nil, parent)
  h:SetPoint("TOPLEFT", 12, -y)
  h:SetPoint("TOPRIGHT", -12, -y)
  h:SetHeight(TIER_H)
  h.goal = tier.goal

  local wash = h:CreateTexture(nil, "BACKGROUND")
  wash:SetAllPoints()
  S.Gradient(wash, { 0.30, 0.55, 0.88, 0.22 }, { 0.30, 0.55, 0.88, 0 }, true)
  local accent = h:CreateTexture(nil, "ARTWORK")
  accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT"); accent:SetWidth(2)
  accent:SetColorTexture(S.Color(S.C.accent))

  h.label = S.Text(h, 12, "accent", "extrabold")
  h.label:SetPoint("LEFT", 10, 0)
  h.label:SetText(L[tier.label])
  S.FitText(h.label, 165, 12)

  h.count = S.Text(h, 11, "muted")
  h.count:SetPoint("RIGHT", -8, 0)
  return h
end

local function createItem(parent, item, y)
  local row = CreateFrame("Button", nil, parent)
  row:SetPoint("TOPLEFT", 16, -y)
  row:SetPoint("TOPRIGHT", -16, -y)
  row:SetHeight(ITEM_H)
  row.id, row.fallback = item[1], item[2]

  local icon = S.Icon(row, 30)
  icon:SetPoint("LEFT", 2, 0)
  row.icon = icon.tex

  row.name = S.Text(row, 13)
  row.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, -1)
  row.name:SetPoint("RIGHT", -2, 0)
  row.name:SetWordWrap(false)

  row.slot = S.Text(row, 11, "muted")
  row.slot:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 9, 1)
  row.slot:SetPoint("RIGHT", -2, 0)
  row.slot:SetWordWrap(false)

  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.id)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  S.RowHighlight(row)
  row:SetScript("OnClick", function(self)
    local _, link = getInfo(self.id)
    if not link then return end
    if IsModifiedClick("CHATLINK") then
      -- (ChatEdit_InsertLink is only a deprecation fallback on newer clients)
      if ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link)
      elseif ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    elseif IsModifiedClick("DRESSUP") then DressUpItemLink(link) end
  end)
  return row
end

local function createPanel(f)
  local p = ns.CreateSidePanel(f, L["Rewards"], PANEL_W)

  local y = 46
  p.tiers, p.items = {}, {}
  for _, tier in ipairs(TIERS) do
    p.tiers[#p.tiers + 1] = createTier(p, tier, y)
    y = y + TIER_H + 4
    for _, item in ipairs(tier.items) do
      p.items[#p.items + 1] = createItem(p, item, y)
      y = y + ITEM_H
    end
    y = y + 8
  end

  local hint = S.Text(p, 11, "muted")
  hint:SetJustifyH("CENTER")
  hint:SetPoint("TOPLEFT", 14, -y)
  hint:SetPoint("TOPRIGHT", -14, -y)
  hint:SetText(L["Shift-click: link  -  Ctrl-click: try on"])
  p:SetHeight(y + 34)

  -- names and icons arrive from the server the first time
  p:HookScript("OnShow", function(self)
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ns.RefreshRewards()
  end)
  p:SetScript("OnHide", function(self) self:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end)
  p:SetScript("OnEvent", ns.RefreshRewards)
  return p
end

function ns.CreateRewardsTab(f)
  panel = createPanel(f)
  ns.AddSideTab(f, "rewards", "Interface\\Icons\\INV_Holiday_Christmas_Present_01", -- wrapped gift
    L["Rewards"], L["Library rewards at 10, 20 and 25 books"], panel)
end
