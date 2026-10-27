extends DeckSuite
# Holding interact at a supply station fills a bar over it, in 3D as in 2D, so players can see the
# pick-up coming.

const INTERACT := "interact_wasd"

func after_test() -> void:
	Input.action_release(INTERACT)
	super()

func _view(deck: Node2D) -> View3D:
	return deck.get_node("View3D")

func _magazine(deck: Node2D) -> Node2D:
	return deck.get_node("Magazine")

# One keyboard player, stood on the magazine and holding interact.
func _hold_at_magazine() -> Node2D:
	PlayerRegistry.join(PlayerRegistry.KEYBOARD_WASD)
	var deck := load_deck(0)
	await frames(2)
	var crew: Node2D = get_tree().get_nodes_in_group("crew")[0]
	crew.global_position = _magazine(deck).global_position
	_view(deck).set_3d(true, false)
	Input.action_press(INTERACT)
	await get_tree().create_timer(_magazine(deck).hold_duration * 0.5).timeout
	await drawn_frames(2)
	return deck

func test_nothing_is_shown_while_nobody_is_holding() -> void:
	var deck := load_deck(2)
	_view(deck).set_3d(true, false)
	await drawn_frames(2)
	assert_array(_view(deck).hold_bars().shown()).is_empty()

func test_holding_at_a_station_fills_a_bar_over_it() -> void:
	var deck: Node2D = await _hold_at_magazine()
	var view := _view(deck)
	var bars := view.hold_bars().shown()
	assert_int(bars.size()).is_equal(1)
	assert_float(bars[0].progress).is_between(0.1, 0.99)
	# Over the station on screen: level with it, and above it.
	var station_on_screen := view.hold_bars().on_screen(view.mirror_of(_magazine(deck)).global_position)
	var bar_centre: float = bars[0].position.x + bars[0].size.x / 2.0
	assert_float(absf(bar_centre - station_on_screen.x)).is_less(4.0)
	assert_float(bars[0].position.y).is_less(station_on_screen.y)

func test_the_bars_fill_as_the_2d_bar_does() -> void:
	var deck: Node2D = await _hold_at_magazine()
	var bars := _view(deck).hold_bars().shown()
	assert_float(bars[0].progress).is_equal_approx(_magazine(deck).hold_progress(), 0.05)

func test_the_bars_only_show_in_3d() -> void:
	var deck: Node2D = await _hold_at_magazine()
	_view(deck).set_3d(false, false)
	await drawn_frames(1)
	assert_bool(_view(deck).hold_bars().is_visible_in_tree()).is_false()
