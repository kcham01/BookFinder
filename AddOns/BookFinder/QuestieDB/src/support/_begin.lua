if BookFinder and BookFinder.Skip and BookFinder.Skip("Questie") then return end -- src/support/_begin.lua
--
-- Opens the support-data block. Closed by src/support/_end.lua.

local _, LibQuestieDB = ...; LibQuestieDB = LibQuestieDB.QuestieDB; if LibQuestieDB.__skip then return end
LibQuestieDB.Support.Install(LibQuestieDB.flavor)
