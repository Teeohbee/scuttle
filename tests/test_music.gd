extends GdUnitTestSuite
# Each screen has its own shanty that never runs out, and it carries on unbroken when a scene reloads.

func _music() -> Node:
	return get_tree().root.get_node("Music")

func _wait_until_composed() -> void:
	var started := Time.get_ticks_msec()
	while not _music().is_composed() and Time.get_ticks_msec() - started < 30000:
		await get_tree().process_frame
	assert_bool(_music().is_composed()).override_failure_message("the shanties took over 30 s to write").is_true()

func after_test() -> void:
	_music().stop()

func test_the_harbour_track_loops() -> void:
	await _wait_until_composed()
	var stream: AudioStreamWAV = _music().stream_for(_music().HARBOUR)
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)

func test_the_battle_shuffles_every_deck_shanty_forever() -> void:
	await _wait_until_composed()
	var playlist: AudioStreamPlaylist = _music().stream_for(_music().BATTLE)
	assert_bool(playlist.shuffle).is_true()
	assert_bool(playlist.loop).is_true()
	assert_int(playlist.stream_count).is_equal(_music().BATTLE_SHANTIES.size())
	# A looping stream never ends, so the playlist would never move on from it.
	for i in playlist.stream_count:
		var stream: AudioStreamWAV = playlist.get_list_stream(i)
		assert_int(stream.loop_mode).override_failure_message("shanty %d loops, so the playlist sticks on it" % i) \
			.is_equal(AudioStreamWAV.LOOP_DISABLED)

func test_the_harbour_is_calmer_than_every_battle_shanty() -> void:
	var harbour: Dictionary = Shanty.TRACKS[_music().HARBOUR]
	for name in _music().BATTLE_SHANTIES:
		assert_int(harbour.beats_per_minute).is_less(Shanty.TRACKS[name].beats_per_minute)
		assert_float(harbour.busyness).is_less(Shanty.TRACKS[name].busyness)

func test_the_join_screen_plays_the_harbour_track() -> void:
	var join: Control = auto_free(load("res://src/ui/join_screen.tscn").instantiate())
	get_tree().root.add_child(join)
	assert_str(_music().track()).is_equal(_music().HARBOUR)

func test_the_deck_plays_the_battle_track() -> void:
	PlayerRegistry.reset()
	PlayerRegistry.add_bot()
	var deck: Node2D = auto_free(load("res://src/ship/deck.tscn").instantiate())
	get_tree().root.add_child(deck)
	assert_str(_music().track()).is_equal(_music().BATTLE)
	PlayerRegistry.reset()

func test_setting_sail_fades_the_harbour_out_while_the_battle_starts_at_once() -> void:
	await _wait_until_composed()
	_music().play(_music().HARBOUR)
	_music().play(_music().BATTLE)
	assert_str(_music().track()).is_equal(_music().BATTLE)
	assert_bool(_music().is_playing()).is_true()
	assert_float(_music().volume()).is_equal(_music().VOLUMES[_music().BATTLE])
	assert_str(_music().fading_track()).is_equal(_music().HARBOUR)
	await get_tree().create_timer(_music().FADE_OUT + 0.2).timeout
	assert_str(_music().fading_track()).override_failure_message("the harbour never finished fading").is_empty()

func test_asking_for_the_track_already_playing_doesnt_restart_it() -> void:
	_music().play(_music().BATTLE)
	# A plain connection, not monitor_signals: Music outlives the suite, and gdUnit's monitor stays
	# connected after it's freed, so the next track change crashes Godot.
	var restarts: Array[String] = []
	var count_restart := func(track: String) -> void: restarts.append(track)
	_music().started.connect(count_restart)
	_music().play(_music().BATTLE)
	_music().started.disconnect(count_restart)
	assert_array(restarts).is_empty()
