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

func test_crew_mirrors_follow_the_crew() -> void:
	var deck := load_deck(3)
	await frames(40)
	var view := _view(deck)
	var crew := tree.get_nodes_in_group("crew")
	check_eq(crew.size(), 3, "crew")
	for c in crew:
		var mirror := view.mirror_of(c)
		check(mirror != null, "crew %s has a mirror" % c.name)
		if mirror:
			var want := view.to_3d(c.global_position)
			check_near(mirror.position.distance_to(want), 0.0, 0.15, "crew %s mirror position" % c.name)

func test_stations_and_enemy_are_mirrored() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	for s in tree.get_nodes_in_group("stations"):
		if s is Station:
			check(view.mirror_of(s) != null, "station %s has a mirror" % s.name)
	check(view.mirror_of(deck.get_node("EnemyShip")) != null, "enemy has a mirror")

func test_one_flame_per_burning_cell() -> void:
	var deck := load_deck()
	await frames(2)
	var fire: FireHazard = deck.get_node("Fire")
	fire.ignite_random()
	fire.ignite_random()
	await frames(2)
	check(fire.burning_cells().size() > 0, "something is burning")
	check_eq(_view(deck).flame_count(), fire.burning_cells().size(), "3D flames")
	var cell: Vector2i = fire.burning_cells()[0]
	check(_view(deck).has_flame_at(_view(deck).to_3d(fire.world_of(cell))), "a flame sits on a burning cell")
