extends GdUnitTestSuite
# F3 shows how fast the game is drawing, and hides it again; hidden, it stays out of the way.

func _counter() -> CanvasLayer:
	return get_tree().root.get_node("FpsCounter")

func after_test() -> void:
	if _counter().visible:
		_counter().toggle()

func _press_f3() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F3
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().process_frame

func test_it_starts_hidden_and_idle() -> void:
	assert_bool(_counter().visible).is_false()
	assert_bool(_counter().is_processing()).is_false()

func test_f3_shows_the_frame_rate_and_hides_it_again() -> void:
	await _press_f3()
	assert_bool(_counter().visible).override_failure_message("F3 didn't show the counter").is_true()
	await get_tree().create_timer(0.7).timeout
	assert_str(_counter().text()).override_failure_message("no reading after half a second").contains("FPS")
	await _press_f3()
	assert_bool(_counter().visible).override_failure_message("F3 didn't hide the counter").is_false()
