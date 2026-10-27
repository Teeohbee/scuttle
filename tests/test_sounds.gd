extends GdUnitTestSuite
# Every sound effect is made, short, and audible without clipping; the fire's crackle loops.

var _sounds := Sounds.build()

func test_every_sound_is_short_and_audible_without_clipping() -> void:
	for name in _sounds:
		var stream: AudioStreamWAV = _sounds[name]
		assert_float(stream.get_length()).override_failure_message("%s goes on too long" % name).is_less_equal(3.0)
		var loudest := 0
		for i in range(0, stream.data.size(), 2):
			loudest = maxi(loudest, absi(stream.data.decode_s16(i)))
		assert_int(loudest).override_failure_message("%s peaks at %d" % [name, loudest]).is_between(8000, 32000)

func test_only_the_crackle_loops() -> void:
	for name in _sounds:
		var loops: bool = _sounds[name].loop_mode == AudioStreamWAV.LOOP_FORWARD
		assert_bool(loops).override_failure_message("%s loops: %s" % [name, loops]).is_equal(name == "crackle")

func test_the_same_sounds_every_launch() -> void:
	var again := Sounds.build()
	for name in _sounds:
		assert_bool(again[name].data == _sounds[name].data).override_failure_message("%s changed" % name).is_true()
