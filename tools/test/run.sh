#!/bin/sh
# Offline tests: loads every file the TOC lists, in order, against tools/test/wow.lua, then each tools/test/test_*.lua.
# Usage: tools/test/run.sh [test name filter]
set -e
cd "$(dirname "$0")/../.."
exec lua5.1 tools/test/runner.lua "$@"
