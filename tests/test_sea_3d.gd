extends DeckSuite
# The sea in 3D is alive: a gentle faceted swell that runs past both ships, with foam where it meets
# each hull. It lies flat while the view lines up with the 2D, and never bares a keel or washes a deck.

func _view(deck: Node2D) -> View3D:
	return deck.get_node("View3D")

func _in_3d() -> Node2D:
	var deck := load_deck()
	_view(deck).set_3d(true, false)
	await drawn_frames(2)
	return deck

const SPOTS := [Vector2(0, 0), Vector2(7.5, -3.0), Vector2(-12.0, 9.0), Vector2(20.0, 4.0)]

func _heights(sea: SeaModel) -> Array[float]:
	var out: Array[float] = []
	for p in SPOTS:
		out.append(sea.height_at(p))
	return out

func test_the_sea_swells_and_runs_at_the_game_angle() -> void:
	var deck: Node2D = await _in_3d()
	var sea := _view(deck).sea()
	var first := _heights(sea)
	var spread: float = first.max() - first.min()
	var moved := 0.0
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var now := _heights(sea)
		for i in now.size():
			assert_float(absf(now[i])).override_failure_message("that's not a gentle swell").is_less_equal(SeaModel.SWELL)
			moved = maxf(moved, absf(now[i] - first[i]))
	assert_float(spread).override_failure_message("the sea is flat across").is_greater(0.02)
	assert_float(moved).override_failure_message("the sea stands still").is_greater(0.02)

func test_it_lies_flat_while_lined_up_with_the_2d() -> void:
	var deck: Node2D = await _in_3d()
	var sea := _view(deck).sea()
	_view(deck).pose(0.0)
	for h in _heights(sea):
		assert_float(h).is_equal(0.0)

# The worst case: a wave crest or trough as the ship rolls, heaves and, for the enemy, sinks and lists.
func test_the_swell_never_bares_a_keel_or_washes_a_deck() -> void:
	var crest := SeaModel.LEVEL + SeaModel.SWELL
	var trough := SeaModel.LEVEL - SeaModel.SWELL
	var our_tip := View3D.HEAVE + View3D.ROLL * 30.0   # out at the bow or stern
	assert_float(-View3D.HULL_DEPTH + our_tip).override_failure_message("our keel comes out of the water").is_less(trough)
	assert_float(0.0 - our_tip).override_failure_message("the sea washes over our deck").is_greater(crest)
	var their_tip := EnemyModel.HEAVE + (EnemyModel.ROLL + EnemyModel.LIST) * EnemyModel.BEAM / 2.0 + EnemyModel.ROLL * EnemyModel.LENGTH / 2.0
	assert_float(EnemyModel.KEEL + their_tip).override_failure_message("the enemy's keel comes out of the water").is_less(trough)
	assert_float(EnemyModel.DECK - EnemyModel.SINK - their_tip).override_failure_message("the sea washes over the enemy's deck").is_greater(crest)

func test_foam_runs_round_both_hulls() -> void:
	var deck: Node2D = await _in_3d()
	var view := _view(deck)
	var foe := view.mirror_of(deck.get_node("EnemyShip")) as EnemyModel
	var hulls := view.sea().foam_lines()
	assert_int(hulls.size()).is_equal(2)
	assert_that(hulls[0]).override_failure_message("no foam round our hull").is_equal(view.hull_outline())
	assert_that(hulls[1]).override_failure_message("no foam round the enemy").is_equal(foe.waterline())
	var middle := Vector2.ZERO
	for p in hulls[1]:
		middle += p / hulls[1].size()
	assert_float(middle.distance_to(Vector2(foe.global_position.x, foe.global_position.z))) \
		.override_failure_message("the enemy's foam isn't where the enemy is").is_less(EnemyModel.LENGTH / 4.0)

func test_the_night_sea_is_darker_than_the_day() -> void:
	var deck: Node2D = await _in_3d()
	var view := _view(deck)
	var day := view.sea().color().get_luminance()
	view.toggle_mood()
	assert_float(view.sea().color().get_luminance()).is_less(day)
