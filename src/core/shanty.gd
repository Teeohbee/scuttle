class_name Shanty
extends RefCounted
# Sea shanties the game writes itself. 6/8 time (ONE-two-three FOUR-five-six, the rocking-boat lilt),
# A minor, oom-pah underneath: bass on 1 and 4, chord stabs on 3 and 6, boots and a tambourine.
# The melody is a random walk up and down the scale that lands on a chord note on every strong beat,
# with a fixed seed so the same tune comes out every time. Phrases go A A B A: the second and last
# phrases reuse the first one's rhythm with new notes, which is what makes it sound composed.

const SLOTS_PER_BAR := 6   # eighth notes; strong on 0 and 3
const BARS := 16
const TAIL := 2.0   # seconds of ringing past the loop end, folded back onto the start
# How likely each weak slot is to get a note, before busyness. Long-short (slots 2 and 5) is the shanty
# skip; slots 1 and 4 fill in now and then.
const SLOT_CHANCE := [1.0, 0.3, 0.8, 1.0, 0.3, 0.8]
const PHRASE_RHYTHMS := [0, 0, 1, 0]   # A A B A, four bars each
# A natural minor. Over the E chord the G is raised to G#, which is the salty bit.
const SCALE := [0, 2, 3, 5, 7, 8, 10]
const ROOT := 57   # A3; scale position 7 is A4
const TONIC_POSITION := 7
const LOWEST_POSITION := 4    # E4
const HIGHEST_POSITION := 14  # A5

const AM := [45, 48, 52]
const G := [43, 47, 50]
const E := [40, 44, 47]
# Bars 8 and 16 come home to Am and hold an A, so each half ends like a verse.
const CHORDS := [AM, G, AM, E, AM, G, E, AM]
const CADENCE_BARS := [7, 15]

# beats_per_minute counts the two big beats in each bar, not the eighths.
const TRACKS := {
	"accordion": {"beats_per_minute": 120, "melody_voice": "accordion", "busyness": 0.6, "seed": 7},
	"fiddle": {"beats_per_minute": 132, "melody_voice": "fiddle", "busyness": 0.75, "seed": 19},
}

static func slot_seconds(track: Dictionary) -> float:
	return 60.0 / track.beats_per_minute / 3.0

static func loop_seconds(track: Dictionary) -> float:
	return BARS * SLOTS_PER_BAR * slot_seconds(track)

static func chord_for_bar(bar: int) -> Array:
	return CHORDS[bar % CHORDS.size()]

# The tune as a list of notes: {"slot": eighths from the start, "length": in eighths, "midi": pitch}.
static func melody(track: Dictionary) -> Array[Dictionary]:
	var random := RandomNumberGenerator.new()
	random.seed = track.seed
	var rhythms: Array = []
	for phrase in 2:
		var rhythm: Array[bool] = []
		for slot in 4 * SLOTS_PER_BAR:
			var chance: float = SLOT_CHANCE[slot % SLOTS_PER_BAR]
			rhythm.append(chance >= 1.0 or random.randf() < chance * track.busyness)
		rhythms.append(rhythm)

	var notes: Array[Dictionary] = []
	var position := TONIC_POSITION
	for bar in BARS:
		var chord := chord_for_bar(bar)
		if bar in CADENCE_BARS:
			notes.append({"slot": bar * SLOTS_PER_BAR, "midi": ROOT + 12})
			continue
		var rhythm: Array = rhythms[PHRASE_RHYTHMS[bar / 4]]
		for slot_in_bar in SLOTS_PER_BAR:
			if not rhythm[(bar % 4) * SLOTS_PER_BAR + slot_in_bar]:
				continue
			# Mostly steps, sometimes a skip of two.
			var step := random.randi_range(-1, 1) if random.randf() < 0.75 else random.randi_range(-2, 2)
			position = clampi(position + step, LOWEST_POSITION, HIGHEST_POSITION)
			if slot_in_bar % 3 == 0:
				position = _nearest_chord_tone(position, chord)
			notes.append({"slot": bar * SLOTS_PER_BAR + slot_in_bar, "midi": _pitch(position, chord)})

	# Each note rings until the next one, but never longer than a big beat, so the tune breathes.
	var total := BARS * SLOTS_PER_BAR
	for i in notes.size():
		var next_slot: int = notes[i + 1].slot if i + 1 < notes.size() else total
		notes[i].length = mini(next_slot - notes[i].slot, 3)
	return notes

static func compose(track: Dictionary) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = track.seed
	var slot := slot_seconds(track)
	var buffer := Synth.empty_buffer(loop_seconds(track) + TAIL)

	for bar in BARS:
		var chord := chord_for_bar(bar)
		var bar_start := bar * SLOTS_PER_BAR * slot
		# Oom on 1 and 4: root, then the fifth below.
		Synth.add_note(buffer, bar_start, Synth.note_frequency(chord[0]), 2.5 * slot, "bass", 0.3)
		Synth.add_note(buffer, bar_start + 3 * slot, Synth.note_frequency(chord[0] - 5), 2.5 * slot, "bass", 0.25)
		Synth.add_stomp(buffer, bar_start, 0.35, random)
		Synth.add_stomp(buffer, bar_start + 3 * slot, 0.25, random)
		# Pah on 3 and 6.
		for pah in [2, 5]:
			for note in chord:
				Synth.add_note(buffer, bar_start + pah * slot, Synth.note_frequency(note + 12), 0.8 * slot, "stab", 0.06)
			Synth.add_tambourine(buffer, bar_start + pah * slot, 0.05, random)

	for note in melody(track):
		Synth.add_note(buffer, note.slot * slot, Synth.note_frequency(note.midi), note.length * slot * 0.95,
				track.melody_voice, 0.16)

	return Synth.to_stream(_fold_tail_into_loop(buffer, int(loop_seconds(track) * Synth.MIX_RATE)), true)

static func _pitch(position: int, chord: Array) -> int:
	var midi: int = ROOT + 12 * (position / SCALE.size()) + SCALE[position % SCALE.size()]
	if chord == E and posmod(midi, 12) == 7:
		midi += 1
	return midi

static func _nearest_chord_tone(position: int, chord: Array) -> int:
	for distance in [0, 1, -1, 2, -2]:
		var candidate := clampi(position + distance, LOWEST_POSITION, HIGHEST_POSITION)
		for note in chord:
			if posmod(note, 12) == posmod(_pitch(candidate, chord), 12):
				return candidate
	return position

# Notes still ringing at the loop end are added back onto the start so the loop joins without a click,
# then the whole loop is brought up to the same loudness.
static func _fold_tail_into_loop(buffer: PackedFloat32Array, loop_samples: int) -> PackedFloat32Array:
	var looped := buffer.slice(0, loop_samples)
	for i in buffer.size() - loop_samples:
		looped[i] += buffer[loop_samples + i]
	var loudest := 0.001
	for sample in looped:
		loudest = maxf(loudest, absf(sample))
	for i in looped.size():
		looped[i] *= 0.55 / loudest
	return looped
