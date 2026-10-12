extends DeckSuite
# The deck's odds and ends: hammocks on the rail, gear at the bow, stores on the quarterdeck. Nothing
# solid stands on a tile you can walk on, so in 3D, as in 2D, what you can't walk through is what you see.

const FLAT := 0.02   # metres: as high as anything over a walkable tile may stand

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
		if v.y > FLAT and _walkable(view, v):
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
