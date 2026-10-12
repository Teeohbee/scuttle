extends DeckSuite
# The 3D view draws the deck from 2D state. It must match the 2D, follow it, and stay out of the way.

func _view(deck: Node2D) -> View3D:
	return deck.get_node("View3D")

func _is_wall(hull: TileMapLayer, cell: Vector2i) -> bool:
	return hull.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0

func test_floor_matches_the_walkable_tiles() -> void:
	var deck := load_deck()
	await frames(2)
	var hull: TileMapLayer = deck.get_node("Hull")
	var view := _view(deck)
	var walls := hull.get_used_cells().filter(func(c): return _is_wall(hull, c))
	assert_int(view.floor_count()).is_equal(hull.get_used_cells().size() - walls.size())

func test_quarterdeck_only_covers_wall_tiles() -> void:
	var deck := load_deck()
	await frames(2)
	var hull: TileMapLayer = deck.get_node("Hull")
	var view := _view(deck)
	var stern := view.to_3d(hull.to_global(hull.map_to_local(hull.get_used_rect().end - Vector2i.ONE))).x
	assert_float(view.quarterdeck_start()).is_less(stern)
	var half := hull.tile_set.tile_size.x / 2.0
	for cell in hull.get_used_cells():
		if not _is_wall(hull, cell):
			var aft_edge := view.to_3d(hull.to_global(hull.map_to_local(cell) + Vector2(half, 0))).x
			assert_float(aft_edge).override_failure_message("floor cell %s is under the quarterdeck" % cell) \
				.is_less_equal(view.quarterdeck_start() + 0.001)

func test_hull_outline_encloses_every_tile() -> void:
	var deck := load_deck()
	await frames(2)
	var hull: TileMapLayer = deck.get_node("Hull")
	var view := _view(deck)
	var outline := view.hull_outline()
	assert_int(outline.size()).is_greater(8)
	var half := Vector2(hull.tile_set.tile_size) / 2.0
	var outside := []
	for cell in hull.get_used_cells():
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var at := view.to_3d(hull.to_global(hull.map_to_local(cell) + corner * half))
			if not Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), outline):
				outside.append(cell)
	assert_array(outside).override_failure_message("cells stick out of the hull: %s" % [outside]).is_empty()

func test_bulwark_has_a_gap_at_each_gun_and_nowhere_else() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	var middle := 0.0
	for p in view.hull_outline():
		middle += p.y / view.hull_outline().size()
	var guns: Array[Vector2] = []
	for s in get_tree().get_nodes_in_group("stations"):
		if "phase" in s:
			var at := view.to_3d(s.global_position)
			guns.append(Vector2(at.x, at.z))
	assert_array(guns).has_size(3)
	var gaps := Array(view.bulwark_gaps())
	var on_same_side := func(a: Vector2, b: Vector2) -> bool:
		return signf(a.y - middle) == signf(b.y - middle) and absf(a.x - b.x) < 0.6
	for gun in guns:
		assert_bool(gaps.any(func(g): return on_same_side.call(g, gun))) \
			.override_failure_message("no gap at the gun at %s" % gun).is_true()
	for gap in gaps:
		assert_bool(guns.any(func(g): return on_same_side.call(gap, g))) \
			.override_failure_message("the gap at %s has no gun" % gap).is_true()

func test_crew_mirrors_follow_the_crew() -> void:
	var deck := load_deck(3)
	_view(deck).set_3d(true, false)
	await frames(40)
	var view := _view(deck)
	var crew := get_tree().get_nodes_in_group("crew")
	assert_array(crew).has_size(3)
	for c in crew:
		var mirror := view.mirror_of(c)
		assert_object(mirror).override_failure_message("crew %s has no mirror" % c.name).is_not_null()
		if mirror:
			assert_float(mirror.position.distance_to(view.to_3d(c.global_position))).is_less_equal(0.15)

func test_stations_and_enemy_are_mirrored() -> void:
	var deck := load_deck()
	_view(deck).set_3d(true, false)
	await frames(2)
	var view := _view(deck)
	for s in get_tree().get_nodes_in_group("stations"):
		if s is Station:
			assert_object(view.mirror_of(s)).override_failure_message("station %s has no mirror" % s.name).is_not_null()
	assert_object(view.mirror_of(deck.get_node("EnemyShip"))).is_not_null()

func test_one_flame_per_burning_cell() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	view.set_3d(true, false)
	var fire: FireHazard = deck.get_node("Fire")
	fire.ignite_random()
	fire.ignite_random()
	await drawn_frames(2)
	assert_array(fire.burning_cells()).is_not_empty()
	assert_int(view.flame_count()).is_equal(fire.burning_cells().size())
	var cell: Vector2i = fire.burning_cells()[0]
	assert_bool(view.has_flame_at(view.to_3d(fire.world_of(cell)))).is_true()

func test_starts_in_2d_and_idle() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	assert_bool(view.is_3d).is_false()
	assert_bool(view.is_drawing()).is_false()
	assert_bool(view.is_processing()).is_false()

func test_toggle_switches_to_3d_and_back() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	view.toggle()
	assert_bool(view.is_3d and view.is_drawing()).override_failure_message("not drawing as soon as the switch starts").is_true()
	await get_tree().create_timer(View3D.SWITCH_TIME + 0.3).timeout
	assert_float(view.blend()).is_equal_approx(1.0, 0.001)
	assert_float(view.camera_tilt()).is_equal_approx(View3D.GAME_TILT, 0.01)
	view.toggle()
	await get_tree().create_timer(View3D.SWITCH_TIME + 0.3).timeout
	assert_float(view.blend()).is_equal_approx(0.0, 0.001)
	assert_bool(view.is_drawing() or view.is_processing()).override_failure_message("not idle again in 2D").is_false()

func test_first_switch_starts_transparent_and_posed() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	view.toggle()
	# no frame has passed, so the tween hasn't ticked: this is what the first 3D frame draws
	assert_float(view.opacity()).is_equal(0.0)
	assert_float(view.camera().fov).is_equal_approx(View3D.FLAT_FOV, 0.001)

func test_flat_camera_lines_up_with_the_2d_camera() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	view.set_3d(true, false)
	await frames(2)   # let the SubViewport take the screen size
	view.pose(0.0)
	var cam_2d: Camera2D = deck.get_node("Camera2D")
	# a deck corner should land on the same screen pixel in both views
	var corner := Vector2(16, 16)
	var px_2d := cam_2d.get_canvas_transform() * corner
	var px_3d := view.camera().unproject_position(view.to_3d(corner))
	assert_vector(px_3d).is_equal_approx(px_2d, Vector2(1.5, 1.5))

func test_hud_draws_over_the_3d() -> void:
	var deck := load_deck()
	await frames(1)
	var view := _view(deck)
	for node in deck.find_children("*", "CanvasLayer", false, false):
		if node != view:
			assert_int(node.layer).override_failure_message("%s (layer %d) is not above the 3D (layer %d)" % [node.name, node.layer, view.layer]) \
				.is_greater(view.layer)

func test_cannon_lamp_shows_its_phase() -> void:
	var deck := load_deck()
	_view(deck).set_3d(true, false)
	await frames(2)
	var cannon := deck.get_node("CannonPortFore")
	cannon.phase = cannon.Phase.RUN_OUT
	await drawn_frames(2)
	assert_that(_view(deck).lamp_color(cannon)).is_equal(cannon.PHASE_COLORS[cannon.Phase.RUN_OUT])

func test_shrouds_come_down_on_the_rail_clear_of_the_gun_ports() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	var ends := view.shroud_feet()
	assert_int(ends.size()).is_greater_equal(view.dresser().masts().size() * 2 * 3)   # three a side at least
	var outline := view.hull_outline()
	for foot in ends:
		var at := Vector2(foot.x, foot.z)
		var nearest := INF
		for i in outline.size():
			var edge := Geometry2D.get_closest_point_to_segment(at, outline[i], outline[(i + 1) % outline.size()])
			nearest = minf(nearest, edge.distance_to(at))
		assert_float(nearest).override_failure_message("shroud at %s isn't on the rail" % foot).is_less(0.3)
		assert_float(foot.y).is_equal_approx(View3D.BULWARK_HEIGHT, 0.1)
		for gap in view.bulwark_gaps():
			assert_float(gap.distance_to(at)).override_failure_message("shroud at %s comes down in a gun port" % foot).is_greater(0.4)

func test_a_lantern_at_every_gangway_post_and_mast() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	var dresser := view.dresser()
	var spots: Array[Vector3] = []
	for post in dresser.gangway_posts():
		spots.append(view.cell_centre(post.cell) + Vector3(post.side.x, 0, post.side.y) * 0.4)
	for cell in dresser.masts():
		spots.append(view.cell_centre(cell))
	var lights := view.lanterns()
	assert_int(lights.size()).is_equal(spots.size())
	for spot in spots:
		assert_bool(lights.any(func(l): return Vector2(l.position.x - spot.x, l.position.z - spot.z).length() < 0.6)) \
			.override_failure_message("no lantern by %s" % spot).is_true()
	for light in lights:
		assert_bool(light.shadow_enabled).is_false()

func test_afternoon_by_default_with_the_lanterns_unlit() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	assert_bool(view.is_night()).is_false()
	for light in view.lanterns():
		assert_float(light.light_energy).is_equal(0.0)

func test_night_lights_the_lanterns_and_darkens_the_sky() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	assert_bool(InputMap.has_action("toggle_mood")).is_true()
	var day_sky := view.sky_color()
	view.toggle_mood()
	assert_bool(view.is_night()).is_true()
	assert_float(view.sky_color().get_luminance()).is_less(day_sky.get_luminance())
	for light in view.lanterns():
		assert_float(light.light_energy).is_greater(0.0)
	view.toggle_mood()
	assert_bool(view.is_night()).is_false()
	assert_that(view.sky_color()).is_equal(day_sky)
