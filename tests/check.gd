class_name Check
extends RefCounted
# Base for tests/test_*.gd. See tests/run.gd.

var tree: SceneTree
var errors: Array[String] = []
var _deck: Node2D

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func check_eq(actual, expected, message: String) -> void:
	if actual != expected:
		errors.append("%s: expected %s, got %s" % [message, expected, actual])

func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		errors.append("%s: expected %s +/- %s, got %s" % [message, expected, tolerance, actual])

func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame

# A deck crewed by bots, the way the playtest harness runs it.
func load_deck(bots := 2) -> Node2D:
	PlayerRegistry.reset()
	GameState.reset()
	for i in bots:
		PlayerRegistry.add_bot()
	_deck = load("res://src/ship/deck.tscn").instantiate()
	tree.root.add_child(_deck)
	return _deck

func teardown() -> void:
	if is_instance_valid(_deck):
		_deck.free()
	PlayerRegistry.reset()
