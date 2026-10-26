extends DeckSuite
# The crew are pirate crabs in 3D (the "Pirate crabs on deck" artifact). Players must still tell each
# other apart from above, see who's walking where, and see what each one is carrying.

func _crab(accent := Color.RED, role := 0) -> PirateCrab:
	var crab: PirateCrab = auto_free(PirateCrab.new(accent, role))
	get_tree().root.add_child(crab)
	return crab

func _walk(crab: PirateCrab, step: Vector3, steps := 10) -> void:
	for i in steps:
		crab.position += step
		crab.animate(0.05, false)

func test_each_crew_member_is_a_crab_in_their_colours() -> void:
	var deck := load_deck(3)
	var view: View3D = deck.get_node("View3D")
	view.set_3d(true, false)
	await frames(2)
	for crew_member in get_tree().get_nodes_in_group("crew"):
		var mirror := view.mirror_of(crew_member)
		assert_object(mirror).is_instanceof(PirateCrab)
		assert_that((mirror as PirateCrab).hat_color()).is_equal(crew_member.accent)
		assert_that((mirror as PirateCrab).ring_color()).is_equal(crew_member.accent)

func test_each_of_the_six_roles_dresses_differently() -> void:
	var vertex_counts := []
	for role in PirateCrab.ROLES.size():
		var crab := _crab(Color.RED, role)
		assert_str(crab.role_name()).is_equal(PirateCrab.ROLES[role].name)
		vertex_counts.append(crab.vertex_count())
	for role in vertex_counts.size():
		assert_int(vertex_counts.count(vertex_counts[role])).override_failure_message("%s dresses like another role" % PirateCrab.ROLES[role].name).is_equal(1)

func test_roles_repeat_after_six() -> void:
	assert_str(_crab(Color.RED, 7).role_name()).is_equal(PirateCrab.ROLES[1].name)

func test_a_walking_crab_scuttles_sideways() -> void:
	var crab := _crab()
	_walk(crab, Vector3(0.15, 0, 0))   # 3 m/s along +x
	assert_float(absf(crab.leg_swing())).is_greater(0.05)
	# side on: it faces along z, either way, while it walks along x
	assert_float(absf(sin(crab.rotation.y))).is_less(0.2)

func test_a_still_crab_stands_still() -> void:
	var crab := _crab()
	_walk(crab, Vector3(0.15, 0, 0))
	_walk(crab, Vector3.ZERO, 30)
	assert_float(crab.leg_swing()).is_equal_approx(0.0, 0.01)

func test_a_carrying_crab_lifts_its_claws() -> void:
	var crab := _crab()
	var claws_down := crab.claw_height()
	for i in 20:
		crab.animate(0.05, true)
	assert_float(crab.claw_height()).is_greater(claws_down + 0.1)

func test_held_items_ride_above_the_shell() -> void:
	assert_float(View3D.HELD_HEIGHT).is_equal(PirateCrab.HELD_HEIGHT)
	assert_float(PirateCrab.HELD_HEIGHT).is_greater(PirateCrab.SHELL_TOP)
