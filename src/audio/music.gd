extends Node
# One shanty at a time, and none of it ever runs out. Each scene asks for its track in _ready; asking
# for the one already playing does nothing, so R restarting a battle doesn't restart the music.
#
# The shanties are written by Shanty on a background thread at boot (about half a second each), the
# harbour first since the join screen wants it soonest. A track asked for before it's written starts
# the moment it is.
#
# Changing track fades the old one out quickly while the new one starts at once, on its downbeat. They
# don't crossfade: the two tunes are at different tempos and would trip over each other.

const HARBOUR := "harbour"   # join screen, one loop
const BATTLE := "battle"     # on deck, the battle shanties shuffled
const BATTLE_SHANTIES := ["broadside", "boarding", "grog", "powder_monkey"]
const PLAYS_EACH := 2   # times through each battle shanty before the playlist moves on
const VOLUMES := {
	HARBOUR: -9.0,
	BATTLE: -6.0,
}
const FADE_OUT := 0.6   # seconds for the old track to fade when the track changes
const SILENT_DB := -80.0

signal started(track: String)

var _playing_player := AudioStreamPlayer.new()
var _fading_player := AudioStreamPlayer.new()
var _track := ""
var _fading_track := ""
var _fade_out: Tween
var _streams := {}   # track -> stream, filled in as the composing thread finishes each one
var _composing := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing while the game is paused
	add_child(_playing_player)
	add_child(_fading_player)
	_composing = WorkerThreadPool.add_task(_compose_all)

# Quitting mid-compose waits for the thread, so none is left running as the game shuts down.
func _exit_tree() -> void:
	WorkerThreadPool.wait_for_task_completion(_composing)

func play(track: String) -> void:
	if track == _track:
		return
	_stop_fading()
	# The player that was playing becomes the one fading out, and the idle one takes the new track.
	var outgoing_player := _playing_player
	_playing_player = _fading_player
	_fading_player = outgoing_player
	_fading_track = _track
	_track = track
	if _fading_track != "":
		_fade_out = create_tween().set_ignore_time_scale(true)   # hit-stop mustn't stretch it
		_fade_out.tween_property(_fading_player, "volume_db", SILENT_DB, FADE_OUT)
		_fade_out.tween_callback(_stop_fading)
	_start()
	started.emit(track)

func stop() -> void:
	_stop_fading()
	_track = ""
	_playing_player.stop()

# The track asked for. It may still be being written; is_playing() says whether it's audible yet.
func track() -> String:
	return _track

func is_playing() -> bool:
	return _playing_player.playing

# The track still fading out after a change, or "" once it's gone.
func fading_track() -> String:
	return _fading_track

func volume() -> float:
	return _playing_player.volume_db

func is_composed() -> bool:
	return _streams.has(HARBOUR) and _streams.has(BATTLE)

func stream_for(track: String) -> AudioStream:
	return _streams.get(track)

func _start() -> void:
	if not _streams.has(_track):
		return   # _composed starts it when it arrives
	_playing_player.stream = _streams[_track]
	_playing_player.volume_db = VOLUMES[_track]
	_playing_player.play()

func _stop_fading() -> void:
	if _fade_out:
		_fade_out.kill()
	_fading_player.stop()
	_fading_track = ""

# Runs on the worker thread: everything it makes is handed back to the main thread by call_deferred.
func _compose_all() -> void:
	_composed.call_deferred(HARBOUR, Shanty.compose(Shanty.TRACKS[HARBOUR]))
	var battle := AudioStreamPlaylist.new()
	battle.shuffle = true
	battle.loop = true
	battle.fade_time = 0.0   # each shanty ends on its held A, so the next can come straight in
	battle.stream_count = BATTLE_SHANTIES.size()
	for i in BATTLE_SHANTIES.size():
		var shanty := Shanty.compose(Shanty.TRACKS[BATTLE_SHANTIES[i]])
		# Played through, not looped: a looping stream never ends, so the playlist would never move on.
		var once := shanty.data
		for repeat in PLAYS_EACH - 1:
			shanty.data += once
		shanty.loop_mode = AudioStreamWAV.LOOP_DISABLED
		battle.set_list_stream(i, shanty)
	_composed.call_deferred(BATTLE, battle)

func _composed(track: String, stream: AudioStream) -> void:
	_streams[track] = stream
	if track == _track and not _playing_player.playing:
		_start()
