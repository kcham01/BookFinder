-- BookFinder: loaded last. What ties the three components together beyond their own public APIs
-- (OpenMapAPI, ShortestPathForever.API), which they already use to talk to each other:
--   * one addon-compartment entry and one /bookfinder command for all three
--   * Shortest Path's world map marks as switches in OpenMap's menu, beside Books on map's own
--   * a login note when a standalone copy took a component's place
local ADDON, root = ...
local public = root.public
local OM, SPF, BOOKS = root.OpenMap, root.SPF, root.Books

local PREFIX = "|cff33ff99BookFinder|r: "
local function say(text) print(PREFIX .. text) end

-- Each component's own entry points, when it runs (in here, or as its standalone addon) -----------
local function openMapSettings()
	if SlashCmdList.OPENMAP then SlashCmdList.OPENMAP("") return true end
end
local function pathSettings()
	if SlashCmdList.SHORTESTPATHFOREVER then SlashCmdList.SHORTESTPATHFOREVER("") return true end
end
local function booksPanel()
	if SlashCmdList.BOOKSONMAP then SlashCmdList.BOOKSONMAP("") return true end
end
local function nearby(rest)
	if SlashCmdList.SPFNEAR then SlashCmdList.SPFNEAR(rest or "") return true end
end

local ENTRIES = {
	{ "map", "OpenMap settings", openMapSettings },
	{ "path", "Shortest Path settings", pathSettings },
	{ "books", "Books on map", booksPanel },
	{ "near", "Nearby services", nearby },
}

-- /bookfinder [map|path|books|near ...|status]
local function status()
	for _, key in ipairs({ "OpenMap", "SPF", "Books" }) do
		local c = public.components[key]
		local where = c.active and "built in" or (public.Loaded(c.folder) and "standalone addon" or "off")
		say(("%s: %s"):format(c.title, where))
	end
	local om = OpenMapAPI
	say(("OpenMap API %s, Shortest Path API %s"):format(
		om and (om.major .. "." .. (om.version or 0)) or "-",
		ShortestPathForever and ShortestPathForever.API and tostring(ShortestPathForever.API.version) or "-"))
end

local function help()
	say("/bookfinder map | path | books | near [service] | status")
	say("Each part keeps its own commands too: /openmap, /path, /way, /spfnear, /bom.")
end

SLASH_BOOKFINDER1, SLASH_BOOKFINDER2 = "/bookfinder", "/bfind"
SlashCmdList.BOOKFINDER = function(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "status" then status() return end
	for _, e in ipairs(ENTRIES) do
		if cmd == e[1] then
			if not e[3](rest) then say(e[2] .. " is not available.") end
			return
		end
	end
	help()
end

-- One addon-compartment entry: left-click opens the map, right-click lists each part ---------------
local function compartmentMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then help() return end
	MenuUtil.CreateContextMenu(owner, function(_, menu)
		menu:CreateTitle("BookFinder")
		for _, e in ipairs(ENTRIES) do
			menu:CreateButton(e[2], function() e[3]() end)
		end
	end)
end

_G.BookFinder_OnAddonCompartmentClick = function(frame, button)
	if button == "RightButton" then
		compartmentMenu(frame)
	elseif _G.OpenMap_OnAddonCompartmentClick then
		_G.OpenMap_OnAddonCompartmentClick(frame, button)
	elseif ToggleWorldMap then
		ToggleWorldMap()
	end
end
_G.BookFinder_OnAddonCompartmentEnter = function(_, owner)
	GameTooltip:SetOwner(owner or UIParent, "ANCHOR_LEFT")
	GameTooltip:AddLine("BookFinder")
	GameTooltip:AddLine("OpenMap, Shortest Path and Books on map", 1, 1, 1)
	GameTooltip:AddLine("Left-click: the world map", 0.5, 1, 0.5)
	GameTooltip:AddLine("Right-click: settings of each part", 0.5, 1, 0.5)
	GameTooltip:Show()
end
_G.BookFinder_OnAddonCompartmentLeave = function() GameTooltip:Hide() end

-- Shortest Path's world map marks as switches in OpenMap's menu ------------------------------------
-- Through the game's own setting objects when Shortest Path's settings page made them, so its page
-- shows the change and its callback redraws the map; else straight to its saved table
local MARKS = {
	{ id = "pins", label = "Show boats and zeppelins", icon = "Interface\\Icons\\INV_Misc_Spyglass_03" },
	{ id = "transit", label = "Show lifts and the tram", icon = "Interface\\Icons\\INV_Gizmo_02" },
	{ id = "portals", label = "Show portals", icon = "Interface\\Icons\\Spell_Arcane_PortalStormWind" },
	{ id = "mapFlightMasters", label = "Show flight masters", icon = "Interface\\Icons\\Ability_Mount_Gryphon_01" },
}

local function spfSetting(key)
	return Settings and Settings.GetSetting and Settings.GetSetting("ShortestPathForever_" .. key)
end

local function registerPathToggles()
	local om = OpenMapAPI
	if not (public.Active("SPF") and SPF.db and type(om) == "table" and om.major == 1
		and type(om.RegisterMenuToggle) == "function") then return end
	local L = SPF.L or {}
	for _, m in ipairs(MARKS) do
		pcall(om.RegisterMenuToggle, ADDON, {
			id = "spf." .. m.id,
			label = L[m.label] or m.label,
			icon = m.icon,
			section = "Shortest Path",
			get = function() return SPF.db[m.id] and true or false end,
			set = function(on)
				on = on and true or false
				local setting = spfSetting(m.id)
				if setting and setting.SetValue then pcall(setting.SetValue, setting, on) end
				-- (no settings page yet, or it didn't take: straight to the saved table, and redraw)
				if SPF.db[m.id] ~= on then
					SPF.db[m.id] = on
					if SPF.RefreshMap then SPF.RefreshMap() end
				end
			end,
		})
	end
end

-- Login ------------------------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	-- (after every component's own login setup, which this frame's registration order already follows)
	C_Timer.After(0, registerPathToggles)
	if #public.shadowed > 0 then
		say(("%s also installed on its own: that copy runs, and BookFinder's stands aside. Disable it in the AddOns list to use BookFinder's.")
			:format(table.concat(public.shadowed, ", ")))
	end
end)
