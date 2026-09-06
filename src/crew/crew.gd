extends CharacterBody2D

const SPEED := 90.0

@export var device_id: int = PlayerRegistry.KEYBOARD_WASD
@export var accent: Color = Color.WHITE

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("crew")
	_sprite.modulate = accent

func _physics_process(_delta: float) -> void:
	velocity = PlayerRegistry.move_vector(device_id) * SPEED
	move_and_slide()
