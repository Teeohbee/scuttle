class_name Sounds
extends RefCounted
# Every sound effect in the game, made by Synth from a recipe below. Each is brought up to its own peak
# loudness, so the mix lives in the table in build(): louder for the cannon, quieter for a crew member
# picking something up. The noise is seeded, so a sound comes out the same every launch.

static func build() -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = 1805   # Trafalgar
	return {
		"cannon": _finish(_cannon(random), 0.95),                 # one of ours fires
		"distant_cannon": _finish(_distant_cannon(random), 0.5),  # the enemy fires, across the water
		"crash": _finish(_crash(random), 0.9),                    # their broadside lands on us
		"whoosh": _finish(_whoosh(random), 0.45),                 # a cell catches fire
		"hiss": _finish(_hiss(random), 0.6),                      # a bucket puts some out
		"crackle": _finish(_crackle(random), 0.35, true),         # loops while anything's burning
		"bell": _finish(_bell(), 0.7),                            # the magazine's alight
		"phew": _finish(_phew(), 0.5),                            # ...and it's out
		"pick_up": _finish(_pick_up(random), 0.4),
		"drop": _finish(_drop(random), 0.35),
		"fill": _finish(_fill(random), 0.4),                      # a bucket filled at the water butt
		"powder": _finish(_powder(random), 0.4),                  # into the cannon
		"shot": _finish(_shot(random), 0.55),
		"run_out": _finish(_run_out(random), 0.6),
		"pump": _finish(_pump(random), 0.35),                     # one stroke of the pump
		"victory": _finish(_victory(random), 0.7),
		"defeat": _finish(_defeat(), 0.7),
	}

static func _cannon(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(1.6)
	Synth.add_noise(buffer, 0.0, 0.2, 0.7, 0.7, 0.0, 14.0, random)     # the crack
	Synth.add_slide(buffer, 0.0, 95.0, 32.0, 0.6, 1.0)                 # the boom
	Synth.add_noise(buffer, 0.01, 1.55, 0.5, 0.04, 0.03, 2.5, random)  # the rumble rolling away
	return buffer

# The same gun from a long way off: the crack is lost over the water, and the boom comes softer and lower.
static func _distant_cannon(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(1.8)
	Synth.add_slide(buffer, 0.0, 70.0, 28.0, 0.7, 1.0)
	Synth.add_noise(buffer, 0.0, 1.75, 0.6, 0.03, 0.08, 2.2, random)
	return buffer

# Timber giving way: a thud, then splinters cracking off one after another.
static func _crash(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(1.2)
	Synth.add_slide(buffer, 0.0, 130.0, 45.0, 0.35, 1.0)
	Synth.add_noise(buffer, 0.0, 1.15, 0.5, 0.06, 0.0, 3.5, random)
	for splinter in 7:
		var at := 0.02 + random.randf_range(0.0, 0.3) * (splinter / 7.0 + 0.2)
		Synth.add_noise(buffer, at, 0.03, random.randf_range(0.5, 0.9), 0.9, 0.0, 60.0, random)
		Synth.add_knock(buffer, at, random.randf_range(250.0, 500.0), 0.3, random)
	return buffer

static func _whoosh(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.7)
	Synth.add_noise(buffer, 0.0, 0.7, 1.0, 0.12, 0.2, 4.0, random)
	return buffer

# Water on fire: a splash, then steam hissing off.
static func _hiss(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.9)
	Synth.add_noise(buffer, 0.0, 0.15, 0.8, 0.25, 0.0, 20.0, random)
	Synth.add_noise(buffer, 0.03, 0.85, 0.6, 0.85, 0.08, 3.5, random)
	return buffer

# Two seconds of pops scattered over a low roar. Nothing rings past the end, so it loops cleanly.
static func _crackle(random: RandomNumberGenerator) -> PackedFloat32Array:
	var seconds := 2.0
	var buffer := Synth.empty_buffer(seconds)
	Synth.add_noise(buffer, 0.0, seconds, 0.25, 0.05, 0.0, 0.0, random)
	for pop in 45:
		Synth.add_noise(buffer, random.randf_range(0.0, seconds - 0.03), random.randf_range(0.004, 0.02),
				random.randf_range(0.3, 1.0), 0.7, 0.0, 150.0, random)
	return buffer

# A ship's bell is struck in pairs: ding-ding, ding-ding.
static func _bell() -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(2.4)
	for at in [0.0, 0.28, 0.75, 1.03]:
		Synth.add_note(buffer, at, Synth.note_frequency(76), 1.3, "bell", 1.0)
	return buffer

# The shanty's E chord coming home to A minor on the accordion, the sound of a tune finishing.
static func _phew() -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(1.1)
	for note in [52, 56, 59]:
		Synth.add_note(buffer, 0.0, Synth.note_frequency(note + 12), 0.18, "stab", 1.0)
	for note in [57, 60, 64]:
		Synth.add_note(buffer, 0.22, Synth.note_frequency(note + 12), 0.85, "accordion", 0.5)
	return buffer

static func _pick_up(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.2)
	Synth.add_knock(buffer, 0.0, 420.0, 1.0, random)
	Synth.add_knock(buffer, 0.05, 560.0, 0.8, random)
	return buffer

static func _drop(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.2)
	Synth.add_knock(buffer, 0.0, 260.0, 1.0, random)
	return buffer

# Bubbles rising as the bucket goes under.
static func _fill(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.6)
	Synth.add_noise(buffer, 0.0, 0.5, 0.4, 0.2, 0.0, 6.0, random)
	for bubble in 5:
		var at := 0.04 + bubble * 0.08
		Synth.add_slide(buffer, at, 450.0 + bubble * 110.0, 1000.0 + bubble * 140.0, 0.07, 0.5)
	return buffer

# Powder poured down the barrel: a soft sandy shush.
static func _powder(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.4)
	Synth.add_noise(buffer, 0.0, 0.4, 1.0, 0.45, 0.04, 7.0, random)
	return buffer

# An iron ball rolled in: a heavy clunk with a short metal ring.
static func _shot(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.5)
	Synth.add_knock(buffer, 0.0, 150.0, 1.0, random)
	Synth.add_slide(buffer, 0.0, 410.0, 405.0, 0.4, 0.25)
	return buffer

# The gun rumbling forward on its wooden wheels.
static func _run_out(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.5)
	Synth.add_noise(buffer, 0.0, 0.4, 0.5, 0.05, 0.03, 5.0, random)
	for bump in 4:
		Synth.add_knock(buffer, bump * 0.07, random.randf_range(85.0, 110.0), 1.0 - bump * 0.15, random)
	return buffer

# A squeak of the handle and a slosh of water.
static func _pump(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(0.4)
	Synth.add_slide(buffer, 0.0, 950.0, 1250.0, 0.12, 0.35)
	Synth.add_noise(buffer, 0.1, 0.3, 0.8, 0.15, 0.03, 9.0, random)
	return buffer

# Up an A major chord, the shanty's minor turned bright, and boots on the deck.
static func _victory(random: RandomNumberGenerator) -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(2.2)
	var notes := [57, 61, 64, 69]
	for i in notes.size():
		Synth.add_note(buffer, i * 0.13, Synth.note_frequency(notes[i] + 12), 1.7 - i * 0.13, "accordion", 0.4)
		Synth.add_stomp(buffer, i * 0.13, 0.5, random)
	Synth.add_note(buffer, 0.0, Synth.note_frequency(45), 1.8, "bass", 0.6)
	return buffer

# Down the minor scale to a low A, slowing as it sinks.
static func _defeat() -> PackedFloat32Array:
	var buffer := Synth.empty_buffer(2.6)
	var at := 0.0
	for step in [[64, 0.3], [62, 0.35], [60, 0.42], [59, 0.5]]:   # note, then the gap after it
		Synth.add_note(buffer, at, Synth.note_frequency(step[0]), 0.4, "accordion", 0.5)
		at += step[1]
	Synth.add_note(buffer, at, Synth.note_frequency(57), 1.2, "accordion", 0.5)
	Synth.add_note(buffer, at, Synth.note_frequency(33), 1.2, "bass", 0.6)
	return buffer

static func _finish(buffer: PackedFloat32Array, peak: float, loops := false) -> AudioStreamWAV:
	var loudest := 0.001
	for sample in buffer:
		loudest = maxf(loudest, absf(sample))
	for i in buffer.size():
		buffer[i] *= peak / loudest
	return Synth.to_stream(buffer, loops)
