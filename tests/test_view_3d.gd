extends Check
# The 3D view draws the deck from 2D state. It must match the 2D, follow it, and stay out of the way.

func _view(deck: Node2D) -> View3D:
	return deck.get_node("View3D")

func _wall_cells(hull: TileMapLayer) -> int:
	var n := 0
	for cell in hull.get_used_cells():
		if hull.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0:
			n += 1
	return n

func test_walls_match_the_collision_tiles() -> void:
	var deck := load_deck()
	await frames(2)
	var hull: TileMapLayer = deck.get_node("Hull")
	check(_wall_cells(hull) > 0, "the hull has walls")
	check_eq(_view(deck).wall_count(), _wall_cells(hull), "3D walls")
	check_eq(_view(deck).floor_count(), hull.get_used_cells().size() - _wall_cells(hull), "3D floor tiles")
