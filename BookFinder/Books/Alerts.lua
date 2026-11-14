-- Book cards: short notices at the top of the screen, one at a time, queued.
--
--   "Book nearby!"  (blue, the map's ping)   within 50 yards of a book the player still needs; again once 100 yards away
--   "Book found!"   (green)                  the book, and a bar to the next reward
--   "<n> books: hand them in at the library!" (gold, the quest-complete sound)  a reward reached
-- A card slides in, waits (longer while the pointer is on it), and fades. Left-click opens the books, right-click
-- puts it away. Drawn in the game's tooltip style, its border in the card's colour.

local _, BF = ...
local L = BF.L

local Books = BF.Books
local Alerts = { queue = {} }
BF.BookAlerts = Alerts

local NEARBY, REARM = 50, 100
local HOLD = 6

local COLOURS = {
	nearby = { 0.35, 0.65, 1 },
	found = { 0.35, 1, 0.45 },
	goal = { 1, 0.82, 0 },
}

-- The card -------------------------------------------------------------------------------------------------------

local card = CreateFrame("Button", "BookFinderBookCard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
card:SetSize(320, 68)
card:SetPoint("TOP", UIParent, "TOP", 0, -150)
card:SetFrameStrata("HIGH")
card:Hide()
card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
if card.SetBackdrop then
	card:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	card:SetBackdropColor(0.05, 0.05, 0.07, 0.92)
end

card.Icon = card:CreateTexture(nil, "ARTWORK")
card.Icon:SetSize(42, 42)
card.Icon:SetPoint("LEFT", 12, 0)
card.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

card.Title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
card.Title:SetPoint("TOPLEFT", card.Icon, "TOPRIGHT", 10, 2)
card.Title:SetPoint("RIGHT", -10, 0)
card.Title:SetJustifyH("LEFT")

card.Text = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
card.Text:SetPoint("TOPLEFT", card.Title, "BOTTOMLEFT", 0, -3)
card.Text:SetPoint("RIGHT", -10, 0)
card.Text:SetJustifyH("LEFT")

card.Detail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
card.Detail:SetPoint("TOPLEFT", card.Text, "BOTTOMLEFT", 0, -2)
card.Detail:SetPoint("RIGHT", -10, 0)
card.Detail:SetJustifyH("LEFT")
card.Detail:SetTextColor(0.75, 0.75, 0.75)

card.Bar = CreateFrame("StatusBar", nil, card)
card.Bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
card.Bar:SetHeight(6)
card.Bar:SetPoint("BOTTOMLEFT", card.Icon, "BOTTOMRIGHT", 10, 0)
card.Bar:SetPoint("RIGHT", -12, 0)

-- The countdown: a thin line along the foot that shortens while the card waits.
card.Countdown = card:CreateTexture(nil, "OVERLAY")
card.Countdown:SetColorTexture(1, 1, 1, 0.5)
card.Countdown:SetHeight(1)
card.Countdown:SetPoint("BOTTOMLEFT", 6, 5)

local showing, left, fading = nil, 0, 0

local function finish()
	card:Hide()
	showing = nil
	Alerts:ShowNext()
end

card:SetScript("OnUpdate", function(self, elapsed)
	if fading > 0 then
		fading = fading - elapsed
		self:SetAlpha(math.max(0, fading / 0.4))
		if fading <= 0 then finish() end
		return
	end
	-- Slide in over the first moments.
	local shown = HOLD - left
	if shown < 0.3 then
		self:SetAlpha(shown / 0.3)
		self:ClearAllPoints()
		self:SetPoint("TOP", UIParent, "TOP", 0, -150 + 20 * (1 - shown / 0.3))
	else
		self:SetAlpha(1)
	end
	if not self:IsMouseOver() then left = left - elapsed end
	self.Countdown:SetWidth(math.max(1, (self:GetWidth() - 12) * math.max(0, left) / HOLD))
	if left <= 0 then fading = 0.4 end
end)

card:SetScript("OnClick", function(_, button)
	if button == "LeftButton" and BF.BooksTab then BF.BooksTab:Open() end
	fading = 0.4
end)

local function present(alert)
	showing, left, fading = alert, HOLD, 0
	local c = COLOURS[alert.kind]
	if card.SetBackdropBorderColor then card:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
	card.Title:SetText(alert.title)
	card.Title:SetTextColor(c[1], c[2], c[3])
	card.Text:SetText(alert.text or "")
	card.Detail:SetText(alert.detail or "")
	card.Icon:SetTexture(alert.icon or "Interface\\Icons\\INV_Misc_Book_09")
	if alert.bar then
		card.Bar:SetMinMaxValues(0, alert.bar[2])
		card.Bar:SetValue(alert.bar[1])
		card.Bar:SetStatusBarColor(c[1], c[2], c[3])
		card.Bar:Show()
	else
		card.Bar:Hide()
	end
	if alert.sound then PlaySound(alert.sound, "Master") end
	card:SetAlpha(0)
	card:Show()
end

function Alerts:ShowNext()
	if showing then return end
	local alert = table.remove(Alerts.queue, 1)
	if alert then present(alert) end
end

function Alerts:Add(alert)
	Alerts.queue[#Alerts.queue + 1] = alert
	Alerts:ShowNext()
end

-- What makes a card ------------------------------------------------------------------------------------------------

BF:Listen("BF_BOOK_FOUND", function(_, book)
	if not BF:Get("books.notifyCollected") then return end
	local done = Books:DoneCount()
	local nextReward = Books:NextReward()
	Alerts:Add({
		kind = "found", title = L["Book found!"], text = Books:Name(book), icon = Books:Icon(book),
		detail = nextReward and L["%d/%d to the %s"]:format(done, nextReward.goal, L[nextReward.label]:lower()) or
			L["Books: %d/%d"]:format(done, Books:Count()),
		bar = nextReward and { done, nextReward.goal } or nil,
	})
end)

BF:Listen("BF_BOOK_GOAL", function(_, goal)
	for _, r in ipairs(Books.REWARDS) do
		if r.goal == goal then
			Alerts:Add({
				kind = "goal", title = L["%d books: hand them in at the library!"]:format(goal),
				text = L["%s unlocked"]:format(L[r.label]),
				icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(r.items[1]) or nil,
				sound = SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878,
			})
		end
	end
end)

-- Nearby: within 50 yards of a book the player needs (re-armed at 100 yards).
local armed = {}
local function checkNearby()
	if not BF:Get("books.alertNearby") then return end
	local instance, px, py = BF.Zones:PlayerWorld()
	if not instance then return end
	for _, book in ipairs(Books.list) do
		if not Books:IsDone(book) then
			for _, place in ipairs(Books:Places(book)) do
				local i, x, y = BF.Zones:ToWorld(place.map, place.x, place.y)
				if i == instance then
					local d = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
					local key = book.key .. place.map .. place.x
					if d <= NEARBY and armed[key] ~= false then
						armed[key] = false
						Alerts:Add({
							kind = "nearby", title = L["Book nearby!"], text = Books:Name(book), icon = Books:Icon(book),
							detail = ("%s (%s) - %d %s"):format(L[book.place or ""], BF.Zones:FormatCoords(place.x, place.y), math.floor(d + 0.5), L["yd"]),
							sound = SOUNDKIT and SOUNDKIT.MAP_PING or 3175,
						})
						BF:Print(L["book nearby: %s - %s (%s), %d yd"], Books:Name(book), L[book.place or ""], BF.Zones:FormatCoords(place.x, place.y), math.floor(d + 0.5))
					elseif d > REARM then
						armed[key] = nil
					end
				end
			end
		end
	end
end

BF:At("world", function() BF:Every(1, checkNearby) end)

--- Every card once, to see them (/bf books test).
function Alerts:Test()
	local book = Books.list[1]
	BF:Send("BF_BOOK_FOUND", book)
	Alerts:Add({ kind = "nearby", title = L["Book nearby!"], text = Books:Name(book), icon = Books:Icon(book),
		detail = L[book.place], sound = SOUNDKIT and SOUNDKIT.MAP_PING or 3175 })
	BF:Send("BF_BOOK_GOAL", 10)
end
