# Cross-checks against other addons (run by hand)

These load another addon's own files **from outside the repository** (the owner's zip, unpacked somewhere) to prove
BookFinder speaks its protocol byte for byte. Nothing of theirs is copied here; the scripts are BookFinder's.

    lua5.1 tools/check/questie_serial.lua <folder holding Questie/> .   # serializer: same bytes, read both ways
    lua5.1 tools/check/addon_escape.lua  <folder holding Questie/> .    # LibDeflate's addon-channel escape

Last run: Questie 12.9.0 (with its LibDeflate): every sample the same bytes, both directions; 500 random strings
escaped and unescaped the same both ways.
