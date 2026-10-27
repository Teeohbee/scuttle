extends GdUnitTestSuite
# The game's own sea shanties: the same tune every time, in step with the chords, and a loop that joins up.

const TRACK := {"beats_per_minute": 120, "melody_voice": "accordion", "busyness": 0.6, "seed": 7}

func test_the_same_seed_writes_the_same_tune() -> void:
	assert_array(Shanty.melody(TRACK)).is_equal(Shanty.melody(TRACK))

func test_a_different_seed_writes_a_different_tune() -> void:
	var other := TRACK.duplicate()
	other.seed = 8
	assert_array(Shanty.melody(other)).is_not_equal(Shanty.melody(TRACK))

func test_every_strong_beat_lands_on_a_note_of_the_chord() -> void:
	for note in Shanty.melody(TRACK):
		if note.slot % 3 != 0:
			continue
		var bar: int = note.slot / Shanty.SLOTS_PER_BAR
		var pitch_classes := Shanty.chord_for_bar(bar).map(func(n: int) -> int: return n % 12)
		assert_bool(note.midi % 12 in pitch_classes) \
			.override_failure_message("bar %d slot %d: %d isn't in the chord" % [bar + 1, note.slot % 6, note.midi]).is_true()

func test_each_half_ends_on_a_held_a() -> void:
	var notes := Shanty.melody(TRACK)
	for bar in Shanty.CADENCE_BARS:
		var in_bar := notes.filter(func(n: Dictionary) -> bool: return n.slot / Shanty.SLOTS_PER_BAR == bar)
		assert_int(in_bar.size()).is_equal(1)
		assert_int(in_bar[0].midi % 12).override_failure_message("bar %d doesn't end on A" % [bar + 1]).is_equal(9)

func test_the_tune_stays_in_a_minor_with_a_raised_g_over_e() -> void:
	var a_minor := [9, 11, 0, 2, 4, 5, 7]
	for note in Shanty.melody(TRACK):
		var chord := Shanty.chord_for_bar(note.slot / Shanty.SLOTS_PER_BAR)
		var allowed := a_minor.duplicate()
		if chord == Shanty.E:
			allowed[6] = 8
		assert_bool(note.midi % 12 in allowed).override_failure_message("%d is out of key" % note.midi).is_true()

func test_the_loop_is_sixteen_bars_long_and_neither_silent_nor_clipping() -> void:
	var stream := Shanty.compose(TRACK)
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_float(stream.get_length()).is_equal_approx(Shanty.loop_seconds(TRACK), 0.01)
	var loudest := 0
	for i in range(0, stream.data.size(), 2):
		loudest = maxi(loudest, absi(stream.data.decode_s16(i)))
	assert_int(loudest).is_between(15000, 32000)
