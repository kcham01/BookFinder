-- Quest icons in the quest giver's window: each quest shows its map icon instead of the game's two.

local function setup()
	World.player.level = 10
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	Login()
end

return {
	["an available quest gets the map's '!', a low-level one the grey '!'"] = function(BF)
		setup()
		local b = World.GossipButton(GossipSharedAvailableQuestButtonMixin, { questID = 33 })
		expect(b.Icon.texture ~= "game-available", "the game's icon replaced")
		local grey = World.GossipButton(GossipSharedAvailableQuestButtonMixin, { questID = 33, isTrivial = true })
		expect(grey.Icon:GetAlpha() < b.Icon:GetAlpha(), "the low-level icon dimmed (and greyed)")
	end,

	["a quest in the log: '?' when ready, the grey '?' when not"] = function(BF)
		setup()
		local done = World.GossipButton(GossipSharedActiveQuestButtonMixin, { questID = 7, isComplete = true })
		local notYet = World.GossipButton(GossipSharedActiveQuestButtonMixin, { questID = 7, isComplete = false })
		expect(done.Icon.texture ~= "game-active", "replaced")
		expect(notYet.Icon.texture ~= done.Icon.texture, "not ready: the grey '?'")
	end,

	["off: the game's icons stay"] = function(BF)
		setup()
		BF:Set("quests.frameIcons", false)
		local b = World.GossipButton(GossipSharedAvailableQuestButtonMixin, { questID = 33 })
		equal(b.Icon.texture, "game-available", "the game's")
	end,
}
