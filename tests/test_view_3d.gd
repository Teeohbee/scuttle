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
	_view(deck).set_3d(true, false)
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
	_view(deck).set_3d(true, false)
	await frames(2)
	var view := _view(deck)
	for s in tree.get_nodes_in_group("stations"):
		if s is Station:
			check(view.mirror_of(s) != null, "station %s has a mirror" % s.name)
	check(view.mirror_of(deck.get_node("EnemyShip")) != null, "enemy has a mirror")

func test_one_flame_per_burning_cell() -> void:
	var deck := load_deck()
	await frames(2)
	_view(deck).set_3d(true, false)
	var fire: FireHazard = deck.get_node("Fire")
	fire.ignite_random()
	fire.ignite_random()
	await frames(2)
	check(fire.burning_cells().size() > 0, "something is burning")
	check_eq(_view(deck).flame_count(), fire.burning_cells().size(), "3D flames")
	var cell: Vector2i = fire.burning_cells()[0]
	check(_view(deck).has_flame_at(_view(deck).to_3d(fire.world_of(cell))), "a flame sits on a burning cell")

func test_starts_in_2d_and_idle() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	check(not view.is_3d, "starts in 2D")
	check(not view.is_drawing(), "3D isn't drawn in 2D")
	check(not view.is_processing(), "3D doesn't process in 2D")

func test_toggle_switches_to_3d_and_back() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	view.toggle()
	check(view.is_3d and view.is_drawing(), "drawing as soon as the switch starts")
	await tree.create_timer(View3D.SWITCH_TIME + 0.3).timeout
	check_near(view.blend(), 1.0, 0.001, "fully 3D")
	check_near(view.camera_tilt(), View3D.GAME_TILT, 0.01, "camera at the game angle")
	view.toggle()
	await tree.create_timer(View3D.SWITCH_TIME + 0.3).timeout
	check_near(view.blend(), 0.0, 0.001, "fully 2D")
	check(not view.is_drawing() and not view.is_processing(), "idle again in 2D")

func test_flat_camera_lines_up_with_the_2d_camera() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	view.set_3d(true, false)
	await frames(2)   # let the SubViewport take the screen size
	view.pose(0.0)
	var cam_2d: Camera2D = deck.get_node("Camera2D")
	var cam_3d := view.camera()
	# a deck corner should land on the same screen pixel in both views
	var corner := Vector2(16, 16)
	var px_2d := cam_2d.get_canvas_transform() * corner
	var px_3d := cam_3d.unproject_position(view.to_3d(corner))
	check_near(px_3d.x, px_2d.x, 1.5, "corner x")
	check_near(px_3d.y, px_2d.y, 1.5, "corner y")
