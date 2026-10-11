extends Check

func test_deck_loads_with_crew() -> void:
	load_deck(3)
	await frames(2)
	check_eq(tree.get_nodes_in_group("crew").size(), 3, "crew on deck")
