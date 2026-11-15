return {
	["links: written as Questie writes them, read back as links, clicked into a tooltip"] = function(BF)
		Login()
		equal(BF.Links:Quest(7), "[[2] Kobold Camp Cleanup (7)]", "the text sent")
		local _, msg = World.chatFilters.CHAT_MSG_PARTY(nil, "CHAT_MSG_PARTY", "look: [[2] Kobold Camp Cleanup (7)] ok", "Ada")
		expect(msg:find("|Hquestie:7:", 1, true), "made a link: " .. msg)
		World.linkHandlers.questie("questie:7:Player-1-1")
		expect(table.concat(ItemRefTooltip.lines, "\n"):find("Kobold Camp Cleanup", 1, true), "tooltip")
	end,
}
