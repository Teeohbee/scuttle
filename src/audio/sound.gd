extends Node
# Plays the game's sound effects, all made by Sounds when the game starts (a fraction of a second).
# Paint Puddle's pattern: a pool of players taken in turn, so a sound can start while others are still
# ringing, and a little random pitch so the same sound twice in a row doesn't sound like a machine.

const VOICES := 12
const WOBBLE := 0.05   # +/- share of pitch

signal played(name: String)

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the victory and defeat sounds play over a paused game
	_sounds = Sounds.build()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

func play(name: String, pitch := 1.0) -> void:
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _sounds[name]
	player.pitch_scale = pitch * randf_range(1.0 - WOBBLE, 1.0 + WOBBLE)
	player.play()
	played.emit(name)

func stream_for(name: String) -> AudioStreamWAV:
	return _sounds[name]
