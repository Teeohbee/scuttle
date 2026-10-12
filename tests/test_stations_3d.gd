extends DeckSuite
# Each station has its own model in 3D, sat on its own tile, so players can tell them apart by shape.

func _view(deck: Node2D) -> View3D:
	return deck.get_node("View3D")

func _stations() -> Array:
	return get_tree().get_nodes_in_group("stations").filter(func(s): return s is Station)

func _kind(station: Node) -> String:
	return station.scene_file_path.get_file().get_basename()

func test_each_kind_of_station_has_its_own_model() -> void:
	var deck := load_deck()
	_view(deck).set_3d(true, false)
	await drawn_frames(2)
	var shapes := {}
	for s in _stations():
		var model := _view(deck).mirror_of(s) as StationModel
		assert_object(model).override_failure_message("%s has no station model" % s.name).is_not_null()
		if model:
			assert_str(model.kind).is_equal(_kind(s))
			shapes[model.kind] = model.vertex_count()
	assert_int(shapes.size()).is_equal(6)
	assert_int(shapes.values().reduce(func(seen, n): return seen if n in seen else seen + [n], []).size()) \
		.override_failure_message("two kinds share a model: %s" % shapes).is_equal(6)

func test_stations_stay_on_their_tile_and_out_of_the_passage() -> void:
	var deck := load_deck()
	var view := _view(deck)
	view.set_3d(true, false)
	await drawn_frames(2)
	var middle := view.deck_rect().get_center().y
	for s in _stations():
		var model := view.mirror_of(s) as StationModel
		var at := view.to_3d(s.global_position)
		var body := model.body_aabb()
		assert_float(maxf(at.x - body.position.x, body.end.x - at.x)) \
			.override_failure_message("%s spills along the deck" % s.name).is_less_equal(0.5)
		var inboard := body.end.z - at.z if at.z < middle else at.z - body.position.z
		assert_float(inboard).override_failure_message("%s reaches %.2f m into the passage" % [s.name, inboard]) \
			.is_less_equal(0.55)

func test_cannons_point_out_through_their_gun_port() -> void:
	var deck := load_deck()
	var view := _view(deck)
	view.set_3d(true, false)
	await drawn_frames(2)
	var middle := view.deck_rect().get_center().y
	for cannon in get_tree().get_nodes_in_group("cannons"):
		var muzzle := (view.mirror_of(cannon) as StationModel).basis.z   # the barrel runs along local +z
		var outboard := signf(view.to_3d(cannon.global_position).z - middle)
		assert_float(muzzle.z * outboard).override_failure_message("%s points inboard" % cannon.name).is_greater(0.9)

func test_pump_handle_rocks_while_manned_and_settles_after() -> void:
	var pump: StationModel = auto_free(StationModel.new("pump"))
	var swing := 0.0
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		pump.work_pump(true, get_process_delta_time())
		swing = maxf(swing, absf(pump.handle.rotation.z))
	assert_float(swing).is_greater(0.2)
	until = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		pump.work_pump(false, get_process_delta_time())
	assert_float(absf(pump.handle.rotation.z)).is_less(0.02)
