return {
	["books tab: beside the quest log, the books by set, a tick hides one"] = function(BF)
		Login()
		BF.BooksTab:Open()
		expect(WorldMapFrame:IsShown(), "the map opens")
		expect(BookFinderLogTab_books and BookFinderLogTab_quests, "Quests and Books tabs are there")
		expect(BF.BooksTab:IsShown(), "the books show")
		local book = BF.Books.list[1]
		BF.Books:Tick(book, true)
		expect(BF.Books:IsDone(book), "ticked")
		BF.BooksTab:Refresh()
		BF.LogTabs:Select("quests")
		expect(not BF.BooksTab:IsShown(), "the Quests tab hides the books")
		expect(BF.LogTabs:IsShown("quests"), "and shows the quests")
		equal(#World.errors, 0, "no errors")
	end,
}
