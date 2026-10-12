extends SceneTree
# Minimal check runner (no GUT): every test_* method of every tests/test_*.gd.
#
#   godot --headless -s tests/run.gd
#
# A test script extends RefCounted, gets `tree` set, and calls check(cond, msg).

var failures := 0
var passed := 0
var _script_errors := ScriptErrors.new()

# A script error ends a test early without failing a check, so catch them and count them as failures.
class ScriptErrors extends Logger:
	var seen: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			seen.append("script error: %s (%s:%d)" % [rationale if rationale else code, file, line])

func _initialize() -> void:
	OS.add_logger(_script_errors)
	await process_frame
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for file in files:
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failures += 1
			printerr("FAIL %s - didn't load (parse error?)" % file)
			continue
		for method in script.get_script_method_list():
			if not method.name.begins_with("test_"):
				continue
			var suite = script.new()
			suite.tree = self
			_script_errors.seen.clear()
			await suite.call(method.name)
			suite.errors.append_array(_script_errors.seen)
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
