if BookFinder and BookFinder.Skip and BookFinder.Skip("Questie") then return end ---@type QuestieCompat
local QuestieCompat = QuestieLoader:ImportModule("QuestieCompat")

---@class WatchFrameHook
local WatchFrameHook = QuestieLoader:CreateModule("WatchFrameHook")

local QuestTimerFrame = QuestTimerFrame

function WatchFrameHook.Hide()
    if QuestTimerFrame then
        QuestTimerFrame:Hide()
    end

    QuestieCompat.HideWatchFrame()
end