"""Runs the Party Picker server scenarios outside the game.

Needs Python 3 and the `lupa` package (pip install lupa), which embeds Lua 5.4,
the same major Lua version Script Extender's own scripts are written for.

    python3 tests/run_tests.py
"""
import glob
import json
import os
import sys

from lupa import lua54

HERE = os.path.dirname(os.path.abspath(__file__))
LUA_ROOT = os.path.join(HERE, "..", "src", "Mods", "PartyPicker", "ScriptExtender", "Lua")


def compile_all(lua):
    ok = True
    for path in sorted(glob.glob(os.path.join(LUA_ROOT, "**", "*.lua"), recursive=True)):
        with open(path, encoding="utf-8") as f:
            result = lua.globals().load(f.read(), "@" + os.path.relpath(path, LUA_ROOT))
        if isinstance(result, tuple) and result[0] is None:
            print("SYNTAX:", result[1])
            ok = False
    return ok


# The MCM blueprint: valid JSON (MCM drops a mod's settings whose blueprint does not parse) with exactly
# these settings (1.1.0 ships without the Inspiration section; docs/PLAN_ship_without_inspiration.md).
BLUEPRINT_IDS = ["max_party_size", "teleport_joiners", "block_in_combat", "prompt_long_rest", "auto_restore",
                 "extend_raft", "hope_attire_everyone", "halsin_early"]


def check_blueprint():
    path = os.path.join(HERE, "..", "src", "Mods", "PartyPicker", "MCM_blueprint.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    ids = [s["Id"] for tab in data["Tabs"] for sec in tab["Sections"] for s in sec["Settings"]]
    if ids != BLUEPRINT_IDS:
        print("BLUEPRINT: setting ids are", ids)
        return False
    return True


def main():
    if not check_blueprint():
        return 1
    print("blueprint: %d settings" % len(BLUEPRINT_IDS))
    lua = lua54.LuaRuntime()
    if not compile_all(lua):
        return 1
    # The server and the client each get their own Lua state, as in the game.
    for script in ("test_server.lua", "test_client.lua"):
        lua = lua54.LuaRuntime()
        g = lua.globals()
        g.LUA_ROOT = LUA_ROOT.replace("\\", "/")
        g.TEST_ROOT = HERE.replace("\\", "/")
        try:
            lua.execute('dofile(TEST_ROOT .. "/' + script + '")')
        except Exception as exc:  # lupa raises LuaError
            print(exc)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
