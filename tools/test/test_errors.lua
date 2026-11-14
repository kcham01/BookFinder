return {
	["errors: caught, counted, kept, ready to copy"] = function(BF)
		Login()
		BF:Listen("BF_BOOM", function() error("kaboom") end)
		BF:Send("BF_BOOM")
		BF:Send("BF_BOOM")
		World.errors = {} -- (the test's own record of errors: these were on purpose)
		local kept = BookFinderDB.errors
		equal(#kept, 1, "one kind of error")
		equal(kept[1].count, 2, "counted twice")
		expect(kept[1].message:find("kaboom", 1, true), "the message")
		SlashCmdList.BOOKFINDER("errors")
		expect(BookFinderErrors:IsShown(), "window")
		expect(BookFinderErrors.report:find("kaboom", 1, true), "in the report")
		expect(BookFinderErrors.report:find("interface 16001", 1, true), "the game's version in the report")
	end,
}
