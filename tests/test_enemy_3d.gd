extends DeckSuite
# The enemy in 3D is a rival ship, not a box: its guns face us, it rolls on its own swell, its
# broadside flashes when it fires, and it wears its damage. It sits where players can see all of it.

func _view(deck: Node2D) -> View3D:
	return deck.get_node("View3D")

func _foe(deck: Node2D) -> EnemyModel:
	return _view(deck).mirror_of(deck.get_node("EnemyShip")) as EnemyModel

func _in_3d() -> Node2D:
	var deck := load_deck()
	_view(deck).set_3d(true, false)
	await drawn_frames(2)
	return deck

func test_the_enemy_is_a_ship_with_its_guns_facing_us() -> void:
	var deck: Node2D = await _in_3d()
	var foe := _foe(deck)
	assert_object(foe).override_failure_message("the enemy is still a box").is_not_null()
	assert_int(foe.masts()).is_between(2, 3)
	var ports := foe.gun_ports()
	assert_int(ports.size()).is_greater_equal(4)
	var ours := _view(deck).deck_rect().get_center().y
	for port in ports:
		assert_float(absf(port.z - ours)).override_failure_message("a gun port faces away from us") \
			.is_less(absf(foe.global_position.z - ours))

func test_it_rolls_on_its_own_out_of_step_with_us() -> void:
	var deck: Node2D = await _in_3d()
	var view := _view(deck)
	var foe := _foe(deck)
	assert_bool(view.ship().is_ancestor_of(foe)).override_failure_message("the enemy rolls with us").is_false()
	var rolls := {}
	var apart := 0.0
	var until := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var roll := foe.roll()
		assert_float(absf(roll.x) + absf(roll.z)).override_failure_message("that's not a gentle roll").is_less(0.06)
		rolls[snappedf(roll.x, 0.0001)] = true
		apart = maxf(apart, (roll - view.ship().rotation).length())
	assert_int(rolls.size()).override_failure_message("the enemy sits dead still").is_greater(3)
	assert_float(apart).override_failure_message("the enemy rolls in step with us").is_greater(0.005)

func test_it_holds_still_while_lined_up_with_the_2d() -> void:
	var deck: Node2D = await _in_3d()
	var view := _view(deck)
	view.pose(0.0)
	assert_that(_foe(deck).roll()).is_equal(Vector3.ZERO)
	var sprite := view.to_3d(deck.get_node("EnemyShip").global_position)
	assert_float(_foe(deck).position.x).is_equal(sprite.x)
	assert_float(_foe(deck).position.z).is_equal(sprite.z - View3D.ENEMY_STANDOFF)

func test_its_broadside_flashes_when_it_fires_and_dies_away() -> void:
	var deck: Node2D = await _in_3d()
	var foe := _foe(deck)
	assert_int(foe.lit_flashes()).is_equal(0)
	deck.get_node("EnemyShip").fired.emit()
	var most := 0
	var until := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		most = maxi(most, foe.lit_flashes())
	assert_int(most).override_failure_message("no muzzle flashes").is_greater_equal(foe.gun_ports().size() / 2)
	await get_tree().create_timer(1.5).timeout
	assert_int(foe.lit_flashes()).override_failure_message("the flashes never go out").is_equal(0)

func test_it_shows_more_wear_as_its_hull_drops() -> void:
	var deck: Node2D = await _in_3d()
	var foe := _foe(deck)
	var enemy: EnemyShip = deck.get_node("EnemyShip")
	assert_int(foe.wear_marks()).override_failure_message("a fresh ship looks damaged").is_equal(0)
	enemy.take_damage(enemy.max_hull_hp * 0.3)
	await drawn_frames(2)
	var some := foe.wear_marks()
	assert_int(some).is_greater(0)
	enemy.take_damage(enemy.max_hull_hp * 0.5)
	await drawn_frames(2)
	assert_int(foe.wear_marks()).is_greater(some)

# Every vertex the enemy draws, on the 640x360 screen the HUD is laid out on.
func _on_screen(view: View3D, foe: EnemyModel) -> Rect2:
	var to_screen := view.drawn_size() / Vector2(view.render_size())
	var rect := Rect2()
	var first := true
	for m in foe.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := view.camera().unproject_position(m.global_transform * v) * to_screen
			rect = Rect2(p, Vector2.ZERO) if first else rect.expand(p)
			first = false
	return rect

func test_it_stays_in_frame_and_clear_of_the_enemy_hull_bar() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	var deck: Node2D = await _in_3d()
	var view := _view(deck)
	var hud := deck.get_node("Hud")
	var bar: Rect2 = hud.get_node("EnemyHull").get_global_rect().merge(hud.get_node("EnemyHullLabel").get_global_rect())
	var frame := Rect2(Vector2.ZERO, view.drawn_size())
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:   # all through its roll
		await get_tree().process_frame
		var drawn := _on_screen(view, _foe(deck))
		assert_bool(frame.encloses(drawn)).override_failure_message("the enemy spills out of frame: %s" % drawn).is_true()
		assert_bool(drawn.grow(2).intersects(bar)).override_failure_message("the enemy is under the hull bar: %s" % drawn).is_false()
