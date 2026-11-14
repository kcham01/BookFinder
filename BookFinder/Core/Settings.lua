-- Settings: every setting BookFinder has is declared once, here or in its module, with its default. The settings
-- panel is built from these declarations, so a setting exists in exactly one place.
--
-- Saved variables:
--   BookFinderDB      (account)   profiles = { [profile] = { [key] = value } }, characters = { [name] = profile },
--                                 plus account-wide state modules keep under BookFinderDB.global.
--   BookFinderCharDB  (character) state that belongs to one character (journey, hidden quests, books collected...).
--
-- Only values that differ from the default are stored, so changing a default reaches everyone who never touched it.
-- Messages: BF_SETTING_CHANGED(key, value, old)  BF_PROFILE_CHANGED(profileName)

local _, BF = ...

local Settings = {}
BF.Settings = Settings

local definitions = {}   -- [key] = { key=, default=, min=, max=, choices=, onChange= }
local order = {}         -- keys in declaration order

local DEFAULT_PROFILE = "Default"

local db, profile, profileName

--- Declares a setting. spec: { default = v, min = n, max = n, step = n, choices = {...} }
function Settings:Define(key, spec)
	assert(not definitions[key], "setting defined twice: " .. key)
	assert(spec.default ~= nil, "setting needs a default: " .. key)
	spec.key = key
	definitions[key] = spec
	order[#order + 1] = key
	return key
end

function Settings:Definition(key)
	return definitions[key]
end

function Settings:Keys()
	return order
end

local function characterKey()
	local name, realm = UnitFullName("player")
	return (name or "?") .. " - " .. (realm or GetRealmName() or "?")
end

local function check(key)
	local def = definitions[key]
	if not def then error("unknown setting: " .. tostring(key), 3) end
	return def
end

--- The setting's value (its default until changed).
function BF:Get(key)
	local def = check(key)
	if profile then
		local v = profile[key]
		if v ~= nil then return v end
	end
	return def.default
end

-- Colours are tables {r, g, b, a}: equal when every part is.
local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for i = 1, math.max(#a, #b) do if a[i] ~= b[i] then return false end end
	return true
end

local function clamp(def, value)
	if type(value) == "number" then
		if def.min and value < def.min then value = def.min end
		if def.max and value > def.max then value = def.max end
	end
	return value
end

--- Changes a setting; BF_SETTING_CHANGED(key, value, old) tells everyone who cares.
function BF:Set(key, value)
	local def = check(key)
	assert(type(value) == type(def.default), ("setting %s takes a %s"):format(key, type(def.default)))
	if def.choices then
		local known = false
		for _, c in ipairs(def.choices) do if c == value then known = true end end
		assert(known, ("setting %s has no choice %s"):format(key, tostring(value)))
	end
	value = clamp(def, value)
	local old = BF:Get(key)
	if profile then
		if same(value, def.default) then profile[key] = nil else profile[key] = value end
	end
	if not same(old, value) then BF:Send("BF_SETTING_CHANGED", key, value, old) end
end

function BF:Toggle(key)
	BF:Set(key, not BF:Get(key))
end

--- Back to the default.
function BF:Reset(key)
	BF:Set(key, check(key).default)
end

-- Profiles ----------------------------------------------------------------------------------------------------------

local function sendAll(previous)
	for _, key in ipairs(order) do
		local value = BF:Get(key)
		local old = previous[key]
		if old == nil then old = definitions[key].default end
		if value ~= old then BF:Send("BF_SETTING_CHANGED", key, value, old) end
	end
end

local function snapshot()
	local values = {}
	for _, key in ipairs(order) do values[key] = BF:Get(key) end
	return values
end

function Settings:ProfileName()
	return profileName
end

function Settings:Profiles()
	local names = {}
	for name in pairs(db.profiles) do names[#names + 1] = name end
	table.sort(names)
	return names
end

function Settings:UseProfile(name)
	local previous = snapshot()
	db.profiles[name] = db.profiles[name] or {}
	db.characters[characterKey()] = name
	profileName, profile = name, db.profiles[name]
	sendAll(previous)
	BF:Send("BF_PROFILE_CHANGED", name)
end

--- Copies another profile's values into the current one.
function Settings:CopyProfile(from)
	local source = db.profiles[from]
	if not source or from == profileName then return end
	local previous = snapshot()
	wipe(profile)
	for k, v in pairs(source) do profile[k] = v end
	sendAll(previous)
end

function Settings:DeleteProfile(name)
	if name == profileName or name == DEFAULT_PROFILE then return false end
	db.profiles[name] = nil
	for character, used in pairs(db.characters) do
		if used == name then db.characters[character] = DEFAULT_PROFILE end
	end
	return true
end

--- Every setting of the current profile back to its default.
function Settings:ResetProfile()
	local previous = snapshot()
	wipe(profile)
	sendAll(previous)
end

-- Account and character state for modules (not settings) -----------------------------------------------------------

--- BookFinderDB.global[module], created on first use.
function BF:AccountState(module)
	local g = db.global
	g[module] = g[module] or {}
	return g[module]
end

--- BookFinderCharDB[module], created on first use.
function BF:CharacterState(module)
	local c = BookFinderCharDB
	c[module] = c[module] or {}
	return c[module]
end

BF:At("load", function()
	BookFinderDB = type(BookFinderDB) == "table" and BookFinderDB or {}
	BookFinderCharDB = type(BookFinderCharDB) == "table" and BookFinderCharDB or {}
	db = BookFinderDB
	db.profiles = db.profiles or {}
	db.characters = db.characters or {}
	db.global = db.global or {}
	db.profiles[DEFAULT_PROFILE] = db.profiles[DEFAULT_PROFILE] or {}
	local name = db.characters[characterKey()] or DEFAULT_PROFILE
	if not db.profiles[name] then name = DEFAULT_PROFILE end
	db.characters[characterKey()] = name
	profileName, profile = name, db.profiles[name]
	-- Values saved for settings that no longer exist (or of another type) are dropped quietly.
	for _, p in pairs(db.profiles) do
		for key, value in pairs(p) do
			local def = definitions[key]
			if not def or type(def.default) ~= type(value) then p[key] = nil end
		end
	end
end, 1)
