class_name Synth
extends RefCounted
# A tiny synthesiser: sounds are added into a buffer of samples one note at a time, then the buffer
# becomes an AudioStreamWAV. Ported from Paint Puddle, with reedier voices for sea shanties.

const MIX_RATE := 22050
const VIBRATO_HZ := 5.5

static func empty_buffer(seconds: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(int(seconds * MIX_RATE))
	return buffer

static func to_stream(buffer: PackedFloat32Array, loops: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i in buffer.size():
		bytes.encode_s16(i * 2, int(clampf(buffer[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = bytes
	if loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = buffer.size()
	return stream

static func note_frequency(midi_note: int) -> float:
	return 440.0 * pow(2.0, (midi_note - 69) / 12.0)

# Voices: "accordion", "fiddle", "bass", "stab" (a short squeeze of accordion for the oom-pah's pah).
static func add_note(buffer: PackedFloat32Array, start: float, frequency: float, duration: float,
		voice: String, volume: float) -> void:
	var first := int(start * MIX_RATE)
	for offset in int(duration * MIX_RATE):
		if first + offset >= buffer.size():
			return
		var time := float(offset) / MIX_RATE
		buffer[first + offset] += voice_sample(voice, frequency, time, duration) * volume

static func voice_sample(voice: String, frequency: float, time: float, duration: float) -> float:
	var phase := TAU * frequency * time
	var release := clampf((duration - time) / 0.04, 0.0, 1.0)
	match voice:
		"accordion":
			# Odd harmonics only, a softened square: reedy. Two copies a few cents apart beat against
			# each other like the two reeds in a real accordion.
			var wobble := 0.25 * sin(TAU * VIBRATO_HZ * time)
			var swell := minf(time / 0.025, 1.0)
			return swell * release * (_reed(phase + wobble) + _reed(phase * 1.003)) * 0.5
		"stab":
			var swell := minf(time / 0.01, 1.0)
			return swell * release * (_reed(phase) + _reed(phase * 1.003)) * 0.5 * exp(-time * 6.0)
		"fiddle":
			# A sawtooth (every harmonic, falling off as 1/n), bowed in slowly, with vibrato that only
			# arrives once the note has settled.
			var depth := 0.6 * clampf((time - 0.12) / 0.2, 0.0, 1.0)
			var bowed := phase + depth * sin(TAU * VIBRATO_HZ * time)
			var saw := 0.0
			for n in range(1, 9):
				saw += sin(bowed * n) / n
			return minf(time / 0.05, 1.0) * release * saw * 0.55
		"bass":
			var triangle := 2.0 * absf(2.0 * fposmod(frequency * time, 1.0) - 1.0) - 1.0
			return minf(time / 0.006, 1.0) * release * triangle * exp(-time * 4.0)
	return 0.0

static func _reed(phase: float) -> float:
	return sin(phase) + sin(phase * 3.0) / 3.0 + sin(phase * 5.0) / 5.0 + sin(phase * 7.0) / 9.0

# A boot on the deck: a thump that drops in pitch, with a scuff of noise on top.
static func add_stomp(buffer: PackedFloat32Array, start: float, volume: float, random: RandomNumberGenerator) -> void:
	var first := int(start * MIX_RATE)
	var length := int(0.14 * MIX_RATE)
	var phase := 0.0
	for offset in length:
		if first + offset >= buffer.size():
			return
		var how_far := float(offset) / length
		phase += TAU * lerpf(110.0, 45.0, how_far) / MIX_RATE
		var thump := sin(phase) * (1.0 - how_far) * (1.0 - how_far)
		var scuff := random.randf_range(-0.25, 0.25) * exp(-how_far * 30.0)
		buffer[first + offset] += (thump + scuff) * volume

# Noise with the low end taken out (each sample minus a running average of the last few), so only
# the bright jingle is left.
static func add_tambourine(buffer: PackedFloat32Array, start: float, volume: float, random: RandomNumberGenerator) -> void:
	var first := int(start * MIX_RATE)
	var length := int(0.09 * MIX_RATE)
	var average := 0.0
	for offset in length:
		if first + offset >= buffer.size():
			return
		var noise := random.randf_range(-1.0, 1.0)
		average = lerpf(average, noise, 0.3)
		var how_far := float(offset) / length
		buffer[first + offset] += (noise - average) * exp(-how_far * 5.0) * volume
