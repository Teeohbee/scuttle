#!/usr/bin/env bash
# Runs every gdUnit4 suite in tests/ headless. -c keeps going after a failure so you see them all.
# Pass a suite path to run just that one: tests/run.sh res://tests/test_view_3d.gd
cd "$(dirname "$0")/.." || exit 1
# Import first so Godot knows every class_name, such as DeckSuite, on a fresh clone or after adding a file
godot --headless --path . --import >/dev/null 2>&1
godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a "${1:-res://tests}" -c --ignoreHeadlessMode
