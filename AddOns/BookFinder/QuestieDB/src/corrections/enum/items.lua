if BookFinder and BookFinder.Skip and BookFinder.Skip("Questie") then return end -- Correction constants. Source origins and extraction history: PROVENANCE.md.

local _, LibQuestieDB = ...; LibQuestieDB = LibQuestieDB.QuestieDB; if LibQuestieDB.__skip then return end
local constants = LibQuestieDB.Enum

constants.itemClasses = {
  QUEST = 12,

  -- Forever [add item classes here]
}

constants.dropCorrectionKeys = {
  PSERVER = -2,
  WOWHEAD = -1,

  -- Forever [add drop-correction source keys here]
}
