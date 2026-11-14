-- Text: every line the player reads goes through BF.L, keyed by its English wording. A language file (Locales/)
-- fills BF.L for its client; a line it lacks shows in English rather than as a blank or a key name.

local _, BF = ...

BF.locale = GetLocale()

BF.L = setmetatable({}, {
	__index = function(_, english) return english end,
})

--- For a language file: BF:Translate("deDE", { ["Quests"] = "Quests", ... }) applies when the client is that language.
function BF:Translate(locale, strings)
	if locale ~= BF.locale then return end
	for english, translated in pairs(strings) do
		if translated ~= true then rawset(BF.L, english, translated) end
	end
end
