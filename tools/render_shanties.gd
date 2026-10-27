extends SceneTree
# Writes every shanty in Shanty.TRACKS to a WAV, so you can listen without starting the game.
#
#   godot --headless --path . -s res://tools/render_shanties.gd -- ~/Desktop
#
# Each file holds the loop played twice, so you can hear it join up.

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args() else "."
	for name in Shanty.TRACKS:
		var started := Time.get_ticks_msec()
		var stream := Shanty.compose(Shanty.TRACKS[name])
		stream.data = stream.data + stream.data
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		var path := "%s/shanty_%s.wav" % [out, name]
		stream.save_to_wav(path)
		print("%s: %d ms -> %s" % [name, Time.get_ticks_msec() - started, path])
	quit()
