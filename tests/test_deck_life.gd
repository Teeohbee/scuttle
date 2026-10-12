extends DeckSuite
# Life on deck that isn't gameplay: it belongs in the right place on the ship, it moves, and it costs
# nothing while the 3D view is asleep.

var _view: View3D
var _life: DeckLife

func _setup(in_3d := true) -> void:
	var deck := load_deck()
	_view = deck.get_node("View3D")
	_life = _view.life()
	if in_3d:
		_view.set_3d(true, false)
	await drawn_frames(2)

func _moves(sample: Callable) -> bool:
	var seen := {}
	for i in 20:   # a second: long enough that no swing can be caught at the top of its arc throughout
		await get_tree().create_timer(0.05).timeout
		seen[snappedf(sample.call(), 0.001)] = true
	return seen.size() > 3

func test_the_wheel_and_binnacle_stand_on_the_quarterdeck() -> void:
	await _setup()
	for part in [_life.wheel(), _life.binnacle()]:
		assert_float(part.global_position.x).is_greater(_view.quarterdeck_start())
		assert_float(part.global_position.y).is_greater_equal(View3D.QUARTERDECK_HEIGHT - 0.001)
	assert_bool(await _moves(func(): return _life.wheel().rotation.x)).override_failure_message("the wheel never turns").is_true()

func test_the_flag_flies_at_the_stern_and_waves() -> void:
	await _setup()
	var flag := _life.flag()
	assert_float(flag.global_position.x).is_greater_equal(_view.deck_rect().end.x - 0.5)
	assert_float(flag.global_position.y).is_greater(2.0)
	assert_bool(await _moves(func(): return _life.flag_tip().global_position.z)).override_failure_message("the flag hangs limp").is_true()

func test_the_bell_hangs_at_the_bow_and_swings() -> void:
	await _setup()
	var bell := _life.bell()
	assert_float(bell.global_position.x).is_less(_view.deck_rect().position.x)
	var at := Vector2(bell.global_position.x, bell.global_position.z)
	assert_bool(Geometry2D.is_point_in_polygon(at, _view.hull_outline())).override_failure_message("the bell is overboard").is_true()
	assert_bool(await _moves(func(): return bell.rotation.z)).override_failure_message("the bell never swings").is_true()

func test_nothing_moves_in_2d() -> void:
	await _setup(false)
	assert_bool(await _moves(func(): return _life.flag_tip().global_position.z)).is_false()

func test_the_parrot_perches_on_the_mainmast_top() -> void:
	await _setup()
	var masts := _view.dresser().masts()
	masts.sort()
	var main := _view.cell_centre(masts[masts.size() / 2])
	var parrot := _life.parrot()
	assert_float(Vector2(parrot.global_position.x - main.x, parrot.global_position.z - main.z).length()).is_less(0.8)
	assert_float(parrot.global_position.y).is_between(DeckDresser.TOP_HEIGHT, DeckDresser.TOP_HEIGHT + 0.6)
	assert_bool(await _moves(func(): return _life.parrot_head().rotation.y)).override_failure_message("the parrot never looks about").is_true()

func test_rats_scurry_along_the_rail_and_never_fall_in_a_gun_port() -> void:
	await _setup()
	var rats := _life.rats()
	assert_int(rats.size()).is_equal(3)
	var r := _view.deck_rect()
	var rails := [r.position.y - 0.25, r.end.y + 0.25]
	var start := rats.map(func(rat): return rat.global_position)
	for i in 30:
		await get_tree().create_timer(0.05).timeout
		for rat in rats:
			var at: Vector3 = rat.global_position
			assert_float(at.y).is_equal_approx(View3D.BULWARK_HEIGHT + 0.07, 0.03)
			assert_bool(rails.any(func(z): return absf(at.z - z) < 0.05)).override_failure_message("rat off the rail at %s" % at).is_true()
			for gap in _view.bulwark_gaps():
				assert_float(gap.distance_to(Vector2(at.x, at.z))).override_failure_message("rat in a gun port at %s" % at).is_greater(0.3)
	var moved := 0
	for k in rats.size():
		if rats[k].global_position.distance_to(start[k]) > 0.2:
			moved += 1
	assert_int(moved).override_failure_message("the rats sit still").is_greater(0)
