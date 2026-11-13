"""Offline routing rig: runs Shortest Path's planner and walking search on its shipped data, without the game.

    python3 tools/routing/rig.py                 # the audit (tools/routing/audit.lua)
    python3 tools/routing/rig.py script.lua      # any script; it gets `rig` (see rig.lua)
Needs: pip install lupa
"""
import base64, os, sys, zlib
import lupa.luajit21 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "src", "ShortestPathForever"))

def main():
    lua = lupa.LuaRuntime(encoding=None, unpack_returned_tuples=True)
    def readfile(path):
        with open(path.decode(), "rb") as f:
            return f.read()
    def b64(s):
        return base64.b64decode(s + b"=" * (-len(s) % 4))
    def inflate(s, _method=None):
        try:
            return zlib.decompress(s)
        except zlib.error:
            return zlib.decompress(s, -15)
    rig = lua.eval("function(...) return loadstring((select(2, ...))((...) .. '/rig.lua'), '@rig.lua') end")(HERE.encode(), readfile)
    rig = rig(SRC.encode(), readfile, b64, inflate)
    script = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "audit.lua")
    chunk = lua.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")(readfile(script.encode()), os.path.basename(script).encode())
    chunk(rig, *[a.encode() for a in sys.argv[2:]])

if __name__ == "__main__":
    main()
