extends DeckSuite
# The 3D deck has no walls: each wall tile is dressed as something a ship keeps on deck. What players
# can't walk through must still show something, and each room's edge must be that room's own stores.

const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var _hull: TileMapLayer
var _dresser: DeckDresser

func _setup() -> void:
	var deck := load_deck()
	await frames(2)
	_hull = deck.get_node("Hull")
	_dresser = (deck.get_node("View3D") as View3D).dresser()

func _is_wall(cell: Vector2i) -> bool:
	var data := _hull.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) > 0

func _is_floor(cell: Vector2i) -> bool:
	var data := _hull.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) == 0

func _room(cell: Vector2i) -> String:
	return _hull.get_cell_tile_data(cell).get_custom_data("room") if _is_floor(cell) else ""

func _walls() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _hull.get_used_cells():
		if _is_wall(cell) and not _dresser.is_under_quarterdeck(cell):
			out.append(cell)
	return out

func test_every_wall_beside_walkable_floor_is_dressed() -> void:
	await _setup()
	var bare := []
	var dressed_for_nothing := []
	for cell in _walls():
		var beside_floor := SIDES.any(func(d): return _is_floor(cell + d))
		var kind := _dresser.kind_of(cell)
		if beside_floor and kind == DeckDresser.Kind.NONE:
			bare.append(cell)
		elif not beside_floor and kind != DeckDresser.Kind.NONE:
			dressed_for_nothing.append(cell)
	assert_array(bare).override_failure_message("walls players walk into with nothing drawn: %s" % [bare]).is_empty()
	assert_array(dressed_for_nothing).override_failure_message("dressed walls no one can reach: %s" % [dressed_for_nothing]).is_empty()

func test_edge_pieces_face_the_room_they_belong_to() -> void:
	await _setup()
	var edges := _walls().filter(func(c): return _dresser.kind_of(c) == DeckDresser.Kind.EDGE)
	assert_array(edges).is_not_empty()
	for cell in edges:
		var room := _dresser.room_of(cell)
		assert_str(room).is_not_empty()
		assert_str(_room(cell + _dresser.facing_of(cell))) \
			.override_failure_message("edge at %s is %s's but faces %s" % [cell, room, cell + _dresser.facing_of(cell)]) \
			.is_equal(room)

func test_room_edges_along_the_passage_are_cargo() -> void:
	await _setup()
	# the magazine's edge along the passage, and the pump room's
	for cell in [Vector2i(10, 4), Vector2i(17, 8)]:
		assert_int(_dresser.kind_of(cell)).is_equal(DeckDresser.Kind.EDGE)
	assert_str(_dresser.room_of(Vector2i(10, 4))).is_equal("magazine")
	assert_str(_dresser.room_of(Vector2i(17, 8))).is_equal("pumpRoom")

func test_bitts_only_meet_the_passage() -> void:
	await _setup()
	var bitts := _walls().filter(func(c): return _dresser.kind_of(c) == DeckDresser.Kind.BITT)
	assert_array(bitts).is_not_empty()
	for cell in bitts:
		for d in SIDES:
			assert_str(_room(cell + d)).override_failure_message("bitt at %s touches a room" % cell).is_empty()

func test_dressing_is_one_mesh() -> void:
	await _setup()
	var mesh := _dresser.mesh()
	assert_object(mesh).is_not_null()
	assert_int(mesh.get_surface_count()).is_equal(1)
	assert_int(mesh.surface_get_array_len(0)).is_greater(1000)

func test_gangway_posts_pair_up_across_each_doorway() -> void:
	await _setup()
	var posts := _dresser.gangway_posts()
	assert_array(posts).is_not_empty()
	var at := {}
	for p in posts:
		at[p.cell] = p.side
	for p in posts:
		assert_int(_dresser.kind_of(p.cell)).is_equal(DeckDresser.Kind.EDGE)
		# walk through the doorway: passage floor all the way to a post facing back
		var cell: Vector2i = p.cell + p.side
		assert_bool(_is_floor(cell)).override_failure_message("post at %s faces no doorway" % p.cell).is_true()
		while _is_floor(cell) and _room(cell) == "":
			cell += p.side
		assert_bool(at.get(cell) == -p.side) \
			.override_failure_message("post at %s has no partner across the doorway" % p.cell).is_true()
	# the deck has eight doorways off the passage
	assert_int(posts.size()).is_equal(16)

func test_each_divider_run_is_one_piece_of_deck_furniture() -> void:
	await _setup()
	var runs := _dresser.dividers()
	var covered := {}
	for run in runs:
		var cells: Array = run.cells
		assert_int(cells.size()).is_greater(1)
		for cell in cells:
			assert_bool(covered.has(cell)).override_failure_message("%s is in two dividers" % cell).is_false()
			covered[cell] = true
			assert_bool(cell == cells[0] or cells.has(cell - run.along)) \
				.override_failure_message("divider %s has a gap" % [cells]).is_true()
		assert_str(run.style).is_not_empty()
	var dividers := _walls().filter(func(c): return _dresser.kind_of(c) == DeckDresser.Kind.DIVIDER)
	assert_int(covered.size()).is_equal(dividers.size())
	# three columns of dividers, port and starboard: boats, a grating and lashed cargo, matched across
	assert_int(runs.size()).is_equal(6)
	var styles := {}
	for run in runs:
		styles.get_or_add(run.cells[0].x, {})[run.style] = true
	assert_int(styles.size()).is_equal(3)
	for column in styles:
		assert_int(styles[column].size()).override_failure_message("column %d mixes styles" % column).is_equal(1)

func test_the_pillars_are_masts() -> void:
	await _setup()
	var pillars := [Vector2i(6, 6), Vector2i(15, 6), Vector2i(24, 6)]
	assert_array(_dresser.masts()).contains_exactly_in_any_order(pillars)
	for cell in _walls():
		var alone := not SIDES.any(func(d): return _is_wall(cell + d))
		assert_bool(_dresser.kind_of(cell) == DeckDresser.Kind.MAST) \
			.override_failure_message("%s: a mast is a wall tile standing alone" % cell).is_equal(alone)
