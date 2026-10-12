extends DeckSuite

func test_deck_loads_with_crew() -> void:
	load_deck(3)
	await frames(2)
	assert_int(get_tree().get_nodes_in_group("crew").size()).is_equal(3)
