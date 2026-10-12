extends DeckSuite
# The crew are pirate monkeys in 3D. Players must still tell each other apart from above, see who's
# walking where, and see what each one is carrying.

func _monkey(accent := Color.RED) -> Monkey:
	var m: Monkey = auto_free(Monkey.new(accent, 0))
	get_tree().root.add_child(m)
	return m

func _walk(m: Monkey, step: Vector3, n := 10) -> void:
	for i in n:
		m.position += step
		m.animate(0.05, false)

func test_each_crew_member_is_a_monkey_in_their_colours() -> void:
	var deck := load_deck(3)
	var view: View3D = deck.get_node("View3D")
	view.set_3d(true, false)
	await frames(2)
	for c in get_tree().get_nodes_in_group("crew"):
		var m := view.mirror_of(c)
		assert_object(m).is_instanceof(Monkey)
		assert_that((m as Monkey).hat_color()).is_equal(c.accent)
		assert_that((m as Monkey).ring_color()).is_equal(c.accent)

func test_a_walking_monkey_swings_its_legs_and_faces_the_way_it_goes() -> void:
	var m := _monkey()
	_walk(m, Vector3(0.15, 0, 0))   # 3 m/s along +x
	assert_float(absf(m.leg_swing())).is_greater(0.05)
	assert_float(wrapf(m.rotation.y - PI / 2, -PI, PI)).is_equal_approx(0.0, 0.2)
	_walk(m, Vector3(0, 0, -0.15), 20)
	assert_float(absf(wrapf(m.rotation.y, 0, TAU) - PI)).is_less(0.2)

func test_a_still_monkey_stands_still() -> void:
	var m := _monkey()
	_walk(m, Vector3(0.15, 0, 0))
	_walk(m, Vector3.ZERO, 30)
	assert_float(m.leg_swing()).is_equal_approx(0.0, 0.01)

func test_a_carrying_monkey_holds_its_arms_up() -> void:
	var m := _monkey()
	var down := m.hand_height()
	for i in 20:
		m.animate(0.05, true)
	assert_float(m.hand_height()).is_greater(down + 0.5)
	assert_float(m.hand_height()).is_greater(Monkey.HEIGHT * 0.8)

func test_held_items_sit_above_the_hat() -> void:
	assert_float(View3D.HELD_HEIGHT).is_greater(Monkey.HEIGHT + 0.1)
