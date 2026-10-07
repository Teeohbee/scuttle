extends Camera2D

const DECAY_PER_SECOND := 6.0

var _strength := 0.0

func _ready() -> void:
	add_to_group("shake_camera")

func _process(delta: float) -> void:
	var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	offset = shake_offset * _strength
	if _strength > 0.0:
		_strength = max(_strength - (DECAY_PER_SECOND * delta), 0.0)

func shake(strength: float) -> void:
	_strength = max(strength, _strength)
