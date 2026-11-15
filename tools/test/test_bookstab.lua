return {
	before = function() QuestMapFrame.SetDisplayMode = function(self, mode) self.mode = mode end end,

	["books tab: beside the quest log, the books by set, a tick hides one"] = function(BF)
		Login()
		BF.BooksTab:Open()
		expect(WorldMapFrame:IsShown(), "the map opens")
		expect(BookFinderBooksTab, "the tab is there")
		expect(BF.BooksTab:IsShown(), "the books show")
		local book = BF.Books.list[1]
		BF.Books:Tick(book, true)
		expect(BF.Books:IsDone(book), "ticked")
		BF.BooksTab:Refresh()
		QuestMapFrame:SetDisplayMode("QuestLog")
		expect(not BF.BooksTab:IsShown(), "another tab hides the books")
		equal(#World.errors, 0, "no errors")
	end,
}
