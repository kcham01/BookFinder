if BookFinder and BookFinder.Skip and BookFinder.Skip("Questie") then return end -- src/support/_end.lua
--
-- Closes the support-data block and hands `QuestieLoader` back.

local _, LibQuestieDB = ...; LibQuestieDB = LibQuestieDB.QuestieDB; if LibQuestieDB.__skip then return end
LibQuestieDB.Support.Remove()
