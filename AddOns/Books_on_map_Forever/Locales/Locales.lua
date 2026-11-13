-- Books on map (Forever): localization (chosen in the options; "auto" = client language)
local _, ns = ...

-- game locale, button text, native name (same languages as Dungeon Quests Forever, menu order)
ns.LANGS = {
  { "enUS", "EN", "English" },
  { "frFR", "FR", "Français" },
  { "deDE", "DE", "Deutsch" },
  { "esES", "ES", "Español" },
  { "itIT", "IT", "Italiano" },
  { "ptBR", "PT", "Português" },
  { "ruRU", "RU", "Русский" },
  { "koKR", "KO", "한국어" },
  { "zhCN", "ZH", "简体中文" },
  { "zhTW", "TW", "繁體中文" },
}

-- filled by Locales\*.lua; English strings are the keys
ns.LOCALES = {}
for _, l in ipairs(ns.LANGS) do ns.LOCALES[l[1]] = {} end

-- reward slots and types of the English language, for a client in another language
local en = ns.LOCALES.enUS
en.INVTYPE_NECK = "Neck"
en.INVTYPE_FINGER = "Finger"
en.INVTYPE_RANGED = "Ranged"
en.INVTYPE_RANGEDRIGHT = "Ranged"
en.INVTYPE_SHIELD = "Off Hand"
en.INVTYPE_HOLDABLE = "Held In Off-hand"
en.ITEM_SUBCLASS_2_2 = "Bows"
en.ITEM_SUBCLASS_4_6 = "Shields"

-- client locales without their own strings use the closest language
local CLIENT = { enGB = "enUS", esMX = "esES", ptPT = "ptBR" }

function ns.ClientLang()
  local locale = GetLocale()
  locale = CLIENT[locale] or locale
  return ns.LOCALES[locale] and locale or "enUS"
end

-- active language, set at ADDON_LOADED from the saved choice (ns.ApplyLanguage)
ns.LANG = ns.ClientLang()

function ns.ApplyLanguage(lang)
  ns.LANG = ns.LOCALES[lang] and lang or ns.ClientLang()
end

-- translation in the active language, or nil
function ns.Localized(k) return ns.LOCALES[ns.LANG][k] end

-- a missing translation falls back to the key
ns.L = setmetatable({}, { __index = function(_, k) return ns.LOCALES[ns.LANG][k] or k end })

-- game font of a language: a forced language may need another alphabet than the client's
local FONTS = {
  ruRU = "Fonts\\FRIZQT___CYR.TTF",
  koKR = "Fonts\\2002.TTF",
  zhCN = "Fonts\\ARKai_T.ttf",
  zhTW = "Fonts\\bLEI00D.ttf",
}

function ns.FontPath(lang)
  if lang == ns.ClientLang() then return STANDARD_TEXT_FONT end
  return FONTS[lang] or "Fonts\\FRIZQT__.TTF"
end
