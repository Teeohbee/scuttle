extends DeckSuite
# The deck's odds and ends: hammocks on the rail, gear at the bow, stores on the quarterdeck. Nothing
# solid stands on a tile you can walk on, short of hanging well overhead, so in 3D, as in 2D, what you
# can't walk through is what you see.

const FLAT := 0.02   # metres: as high as anything over a walkable tile may stand
const OVERHEAD := 3.0   # metres: high enough over the crew's heads that it can't be mistaken for a wall

func _view() -> View3D:
	var deck := load_deck()
	await frames(2)
	return deck.get_node("View3D")

func _walkable(view: View3D, p: Vector3) -> bool:
	var cell := view.hull.local_to_map(view.hull.to_local(Vector2(p.x, p.z) * View3D.PX_PER_M))
	var data := view.hull.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) == 0

func _vertices(view: View3D) -> PackedVector3Array:
	var mesh := view.clutter().mesh
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		out += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
	return out

func test_nothing_stands_on_a_tile_you_can_walk_on() -> void:
	var view: View3D = await _view()
	var vertices := _vertices(view)
	assert_int(vertices.size()).is_greater(0)
	for v in vertices:
		if v.y > FLAT and v.y < OVERHEAD and _walkable(view, v):
			fail("clutter stands %.2f m high on a walkable tile at %s" % [v.y, v])
			return

func test_nothing_hangs_off_the_ship() -> void:
	var view: View3D = await _view()
	var outside: PackedVector2Array = Geometry2D.offset_polygon(view.hull_outline(), 0.1)[0]
	for v in _vertices(view):
		if not Geometry2D.is_point_in_polygon(Vector2(v.x, v.z), outside):
			fail("clutter hangs over the side at %s" % v)
			return

func test_hammocks_are_stowed_along_the_rail_clear_of_the_gun_ports() -> void:
	var view: View3D = await _view()
	var hammocks := view.clutter().hammocks()
	var r := view.deck_rect()
	var rails := [r.position.y - 0.25, r.end.y + 0.25]
	assert_int(hammocks.size()).is_greater(20)
	for h in hammocks:
		assert_bool(rails.any(func(z): return absf(h.z - z) < 0.01)).override_failure_message("a hammock off the rail at %s" % h).is_true()
		assert_float(h.y - DeckClutter.HAMMOCK_RADIUS).override_failure_message("a hammock not on the rail top at %s" % h) \
			.is_equal_approx(DeckClutter.RAIL_TOP, 0.01)
		for gap in view.bulwark_gaps():
			assert_float(absf(gap.x - h.x) if absf(gap.y - h.z) < 0.5 else INF) \
				.override_failure_message("a hammock over the gun port at %s" % gap).is_greater(0.5 + DeckClutter.HAMMOCK_LENGTH / 2.0 - 0.01)
	for side in rails:
		var row := hammocks.filter(func(h): return absf(h.z - side) < 0.01)
		assert_int(row.size()).override_failure_message("no hammocks along one side").is_greater(10)

func test_a_windlass_spans_the_bow_clear_of_the_bell_and_the_gangway() -> void:
	var view: View3D = await _view()
	var windlass := view.clutter().windlass()
	var mid := view.deck_rect().get_center().y
	assert_float(windlass.size.z).override_failure_message("the windlass is too short to see").is_greater(3.0)
	assert_bool(windlass.position.z < mid and windlass.end.z > mid).override_failure_message("the windlass is off the centreline").is_true()
	var bell := view.life().bell().position
	assert_bool(bell.x < windlass.position.x - 0.3 or bell.x > windlass.end.x + 0.3).override_failure_message("the windlass runs into the bell").is_true()
	for post in view.dresser().gangway_posts():
		var at := view.cell_centre(post.cell)
		assert_float(at.x).override_failure_message("the windlass is aft of a gangway post").is_greater(windlass.end.x)
	for cell in view.dresser().masts():
		assert_float(view.cell_centre(cell).x).is_greater(windlass.end.x)

func test_stores_on_the_quarterdeck_leave_the_helm_clear() -> void:
	var view: View3D = await _view()
	var stores := view.clutter().stores()
	assert_int(stores.size()).is_greater_equal(3)
	var life := view.life()
	var helm: Array[Vector3] = [life.wheel().position, life.binnacle().position, life.flag().position]
	for at in stores:
		assert_float(at.x).override_failure_message("stores off the quarterdeck at %s" % at).is_greater(view.quarterdeck_start())
		assert_float(at.y).override_failure_message("stores sunk in the quarterdeck at %s" % at).is_equal_approx(View3D.QUARTERDECK_HEIGHT, 0.01)
		for thing in helm:
			assert_float(Vector2(at.x, at.z).distance_to(Vector2(thing.x, thing.z))) \
				.override_failure_message("stores at %s crowd the helm at %s" % [at, thing]).is_greater(1.0)   # half a store's width, then 0.6 m clear

func test_bananas_hang_from_the_mainmast_top_clear_of_the_rigging() -> void:
	var view: View3D = await _view()
	var bunch := view.clutter().bananas()
	var masts := view.dresser().masts()
	masts.sort()
	var mast := view.cell_centre(masts[masts.size() / 2])
	assert_float(Vector2(bunch.x, bunch.z).distance_to(Vector2(mast.x, mast.z))).override_failure_message("the bananas aren't hung off the top") \
		.is_between(0.5, 1.0)
	assert_float(bunch.y).override_failure_message("the bananas are too low to clear heads").is_between(OVERHEAD + 0.3, DeckDresser.TOP_HEIGHT)
	for foot in view.shroud_feet():
		if absf(foot.x - mast.x) > 1.0:
			continue
		var top := mast + Vector3(0, DeckDresser.TOP_HEIGHT - 0.05, signf(foot.z - mast.z) * 0.2)
		var near := Geometry3D.get_closest_point_to_segment(bunch, top, foot)
		assert_float(near.distance_to(bunch)).override_failure_message("the bananas foul a shroud").is_greater(0.3)
	for light in view.lanterns():
		assert_float(light.global_position.distance_to(bunch)).override_failure_message("the bananas crowd a lantern").is_greater(0.5)

func _room_at(view: View3D, p: Vector3) -> String:
	var data := view.hull.get_cell_tile_data(view.hull.local_to_map(view.hull.to_local(Vector2(p.x, p.z) * View3D.PX_PER_M)))
	return data.get_custom_data("room") if data else ""

func test_puddles_lie_in_the_pump_room_clear_of_the_pump() -> void:
	var view: View3D = await _view()
	var pump: Pump = view.get_tree().get_nodes_in_group("stations").filter(func(s): return s is Pump)[0]
	var at := view.to_3d(pump.global_position)
	var puddles := view.clutter().puddles()
	assert_int(puddles.size()).is_equal(3)
	for p in puddles:
		assert_str(_room_at(view, p)).override_failure_message("a puddle outside the pump room at %s" % p).is_equal(_room_at(view, at))
		assert_float(Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z))).override_failure_message("a puddle under the pump").is_greater(1.0)

func test_every_gun_has_tracks_worn_inboard_along_its_recoil() -> void:
	var view: View3D = await _view()
	var mid := view.deck_rect().get_center().y
	var guns := view.get_tree().get_nodes_in_group("stations").filter(func(s): return "phase" in s)
	var scuffs := view.clutter().scuffs()
	assert_int(scuffs.size()).is_equal(guns.size())
	for g in guns:
		var gun := view.to_3d(g.global_position)
		var mine := Array(scuffs).filter(func(s): return absf(s.x - gun.x) < 0.05 and signf(s.z - mid) == signf(gun.z - mid))
		assert_int(mine.size()).override_failure_message("the gun at %s has no tracks" % gun).is_equal(1)
		assert_float(absf(mine[0].z - mid)).override_failure_message("the tracks at %s aren't inboard" % gun).is_less(absf(gun.z - mid))
