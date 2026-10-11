extends SceneTree
# Minimal check runner (no GUT): every test_* method of every tests/test_*.gd.
#
#   godot --headless -s tests/run.gd
#
# A test script extends RefCounted, gets `tree` set, and calls check(cond, msg).

var failures := 0
var passed := 0

func _initialize() -> void:
	await process_frame
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for file in files:
		var script: GDScript = load("res://tests/" + file)
		for method in script.get_script_method_list():
			if not method.name.begins_with("test_"):
				continue
			var suite = script.new()
			suite.tree = self
			await suite.call(method.name)
			if suite.errors.is_empty():
				passed += 1
			else:
				failures += 1
				for e in suite.errors:
					printerr("FAIL %s:%s - %s" % [file, method.name, e])
			if suite.has_method("teardown"):
				suite.teardown()
	print("%d passed, %d failed" % [passed, failures])
	quit(1 if failures else 0)
