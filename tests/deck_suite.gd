@abstract
class_name DeckSuite
extends GdUnitTestSuite
# Base for suites that need a real deck: crewed by bots, the way the playtest harness runs it.

func before_test() -> void:
	PlayerRegistry.reset()
	GameState.reset()

func after_test() -> void:
	PlayerRegistry.reset()

func load_deck(bots := 2) -> Node2D:
	for i in bots:
		PlayerRegistry.add_bot()
	var deck: Node2D = auto_free(load("res://src/ship/deck.tscn").instantiate())
	get_tree().root.add_child(deck)
	return deck

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
