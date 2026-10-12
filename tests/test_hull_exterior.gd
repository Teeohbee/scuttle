extends DeckSuite
# The outside of the hull is dressed, not a bare slab: wales round it above the sea, a lid swung open
# over every gun port, and channels where the shrouds come down. None of it pokes in over the deck.

func _view(deck: Node2D) -> View3D:
	return deck.get_node("View3D")

func _side(view: View3D, p: Vector2) -> float:
	return signf(p.y - view.deck_rect().get_center().y)

func test_wales_run_round_the_hull_above_the_sea() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	var wales := view.wales()
	assert_int(wales.size()).is_greater_equal(2)
	for y in wales:
		assert_float(y).override_failure_message("a wale is under the sea").is_greater(SeaModel.LEVEL + SeaModel.SWELL + 0.1)
		assert_float(y).override_failure_message("a wale is above the deck").is_less(0.0)
	var reach := Rect2(view.hull_outline()[0], Vector2.ZERO)
	for p in view.hull_outline():
		reach = reach.expand(p)
	var dressed := view.hull_exterior().get_aabb()
	assert_float(dressed.position.x).override_failure_message("the wales stop short of the bow").is_less_equal(reach.position.x)
	assert_float(dressed.end.x).override_failure_message("the wales stop short of the stern").is_greater_equal(reach.end.x)

func test_every_gun_port_has_its_lid_swung_open_outboard() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	var lids := view.port_lids()
	assert_int(lids.size()).is_equal(view.bulwark_gaps().size())
	var mid := view.deck_rect().get_center().y
	for gap in view.bulwark_gaps():
		var near := Array(lids).filter(func(l: Vector3): return absf(l.x - gap.x) < 0.3 and _side(view, Vector2(l.x, l.z)) == _side(view, gap))
		assert_int(near.size()).override_failure_message("the port at %s has no lid" % gap).is_equal(1)
		var lid: Vector3 = near[0]
		assert_float(absf(lid.z - mid)).override_failure_message("the lid at %s isn't outboard" % gap).is_greater(absf(gap.y - mid))
		assert_float(lid.y).override_failure_message("the lid at %s is shut" % gap).is_greater(View3D.BULWARK_HEIGHT / 2.0)

func test_every_shroud_comes_down_to_a_channel_outboard() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	var mid := view.deck_rect().get_center().y
	var channels := view.channels()
	assert_int(channels.size()).is_greater(0)
	for foot in view.shroud_feet():
		var under := channels.filter(func(c: Rect2): return absf(foot.x - c.get_center().x) <= c.size.x / 2.0 \
			and signf(c.get_center().y - mid) == signf(foot.z - mid))
		assert_int(under.size()).override_failure_message("the shroud at %s has no channel" % foot).is_equal(1)
		var channel: Rect2 = under[0]
		assert_float(absf(channel.get_center().y - mid)).override_failure_message("the channel at %s is inboard" % foot) \
			.is_greater(absf(foot.z - mid))

func test_nothing_outboard_pokes_in_over_the_deck() -> void:
	var deck := load_deck()
	await frames(2)
	var view := _view(deck)
	var inside: PackedVector2Array = Geometry2D.offset_polygon(view.hull_outline(), -0.03)[0]
	var mesh := view.hull_exterior().mesh
	for s in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if Geometry2D.is_point_in_polygon(Vector2(v.x, v.z), inside):
				fail("the outside dressing reaches in over the deck at %s" % v)
				return
