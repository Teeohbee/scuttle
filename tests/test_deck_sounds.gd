extends DeckSuite
# What happens on deck is heard: every sound comes from the deck's own signals and state, so gameplay
# code never has to ask for one.

var _heard: Array[String] = []

func before_test() -> void:
	super()
	_heard.clear()
	# A plain connection, not monitor_signals: Sound outlives the suite (see test_music.gd).
	Sound.played.connect(_hear)

func after_test() -> void:
	Sound.played.disconnect(_hear)
	super()

func _hear(name: String) -> void:
	_heard.append(name)

func _crab(deck: Node2D) -> Node2D:
	return deck.get_tree().get_nodes_in_group("crew")[0]

func test_our_cannon_booms() -> void:
	var deck := load_deck(0)
	deck.get_tree().get_nodes_in_group("cannons")[0].fired.emit(8.0)
	assert_array(_heard).contains(["cannon"])

func test_the_enemy_fires_from_afar_and_its_broadside_crashes_into_us() -> void:
	var deck := load_deck(0)
	deck.get_node("EnemyShip").fired.emit()
	deck.get_node("EnemyShip").broadside_landed.emit()
	assert_array(_heard).contains(["distant_cannon", "crash"])

func test_loading_a_cannon_is_heard_step_by_step() -> void:
	var deck := load_deck(0)
	var cannon: Node = deck.get_tree().get_nodes_in_group("cannons")[0]
	for phase in [cannon.Phase.POWDERED, cannon.Phase.LOADED, cannon.Phase.RUN_OUT]:
		cannon.phase = phase
		await frames(2)
	assert_array(_heard).contains_exactly(["powder", "shot", "run_out"])

func test_fire_whooshes_up_crackles_and_hisses_out() -> void:
	var deck := load_deck(1)
	var fire: FireHazard = deck.get_node("Fire")
	fire.ignite_random()
	await frames(2)
	assert_array(_heard).contains(["whoosh"])
	assert_bool(deck.get_node("DeckSounds")._crackle.playing).override_failure_message("no crackle").is_true()
	var crab := _crab(deck)
	var bucket: Carryable = auto_free(load("res://src/crew/carryable.tscn").instantiate())
	deck.add_child(bucket)
	bucket.set_kind(Carryable.Kind.BUCKET_WATER)
	crab.held_item = bucket
	crab.global_position = fire.world_of(fire.burning_cells()[0])
	fire.perform_interact(crab)
	await frames(2)
	assert_array(_heard).contains(["hiss"])

func test_the_last_flame_out_silences_the_crackle() -> void:
	var deck := load_deck(1)
	var fire: FireHazard = deck.get_node("Fire")
	fire.ignite_random()
	await frames(2)
	for cell in fire.burning_cells():
		fire._extinguish(cell)
	await frames(2)
	assert_bool(deck.get_node("DeckSounds")._crackle.playing).is_false()

func test_picking_up_and_putting_down_are_heard() -> void:
	var deck := load_deck(1)
	var crab := _crab(deck)
	var item: Carryable = auto_free(load("res://src/crew/carryable.tscn").instantiate())
	deck.add_child(item)
	crab.held_item = item
	await frames(2)
	crab.held_item = null
	await frames(2)
	assert_array(_heard).contains_exactly(["pick_up", "drop"])

func test_filling_a_bucket_bubbles() -> void:
	var deck := load_deck(1)
	var bucket: Carryable = auto_free(load("res://src/crew/carryable.tscn").instantiate())
	deck.add_child(bucket)
	bucket.set_kind(Carryable.Kind.BUCKET_EMPTY)
	_crab(deck).held_item = bucket
	await frames(2)
	bucket.set_kind(Carryable.Kind.BUCKET_WATER)
	await frames(2)
	assert_array(_heard).contains(["fill"])

func test_the_magazine_rings_the_bell_and_sighs_when_saved() -> void:
	var deck := load_deck(0)
	deck.get_node("Fire").fuse_lit.emit()
	deck.get_node("Fire").fuse_out.emit()
	assert_array(_heard).contains(["bell", "phew"])

func test_winning_and_losing_each_have_their_sound() -> void:
	load_deck(0)
	GameState.won.emit()
	GameState.lost.emit("sunk")
	assert_array(_heard).contains(["victory", "defeat"])
