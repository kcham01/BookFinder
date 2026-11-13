-- BookFinder: what stands in for the parts' files it leaves out of the build (tools/build.py's DROP list).
-- Each of those only drew a window or a button that BookFinder replaces: Books on map's welcome page (OpenMap's
-- welcome is the one), its broker launcher and minimap button (BookFinder's one button), and the side panels of
-- its old window (the Library books tab: BooksTab.lua). The rest of Books still calls their entry points, so they
-- are here as no-ops, or as the thing that replaced them.
local _, root = ...
local public = root.public
local BOOKS = root.Books
if not (public and BOOKS) or BOOKS.__skip then return end

local function none() end
local function stand(name, fn)
	if BOOKS[name] == nil then BOOKS[name] = fn end
end

-- Welcome.lua: `/bom welcome` opens the books tab instead
stand("InitWelcome", none)
stand("ShowWelcome", function() if public.OpenBooks then public.OpenBooks() end end)
-- Broker.lua and Minimap.lua: BookFinder's launcher and button
stand("InitBroker", none)
stand("RefreshBroker", none)
stand("InitMinimapButton", none)
stand("UpdateMinimapButton", none)
-- SideTabs.lua and GroupPanel.lua: the old window's side panels (only its create() calls the first three)
stand("CreateSidePanel", none)
stand("AddSideTab", none)
stand("CreateGroupTab", none)
stand("RefreshGroupPanel", none)
