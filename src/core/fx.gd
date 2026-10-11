extends Node

const DEFAULT_DURATION := 0.05
const DEFAULT_SCALE := 0.05

var _stopping := false

func shake(strength: float) -> void:
	var cam := get_tree().get_first_node_in_group("shake_camera")
	if cam:
		cam.shake(strength)

func hit_stop(duration: float = DEFAULT_DURATION, scale: float = DEFAULT_SCALE) -> void:
	# Two guns firing a frame apart must not have the first one's timeout
	# restore normal speed while the second is still mid-stutter.
	if _stopping:
		return
	_stopping = true
	Engine.time_scale = scale
	# The 4th argument is ignore_time_scale - this timer must not itself freeze,
	# or it would wait 1/scale times as long as you asked for and never recover.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false
