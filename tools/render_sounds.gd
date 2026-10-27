extends SceneTree
# Writes every sound effect to a WAV, so you can listen without starting the game.
#
#   godot --headless --path . -s res://tools/render_sounds.gd -- ~/Desktop

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args() else "."
	var started := Time.get_ticks_msec()
	var sounds := Sounds.build()
	print("built %d sounds in %d ms" % [sounds.size(), Time.get_ticks_msec() - started])
	for name in sounds:
		sounds[name].save_to_wav("%s/%s.wav" % [out, name])
	quit()
