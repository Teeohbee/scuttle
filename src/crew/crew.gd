extends CharacterBody2D

const SPEED := 90.0
const REPULSION_RADIUS := 20.0
const REPULSION_STRENGTH := 40.0

@export var device_id: int = PlayerRegistry.KEYBOARD_WASD
@export var accent: Color = Color.WHITE

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("crew")
	_sprite.modulate = accent

func _physics_process(_delta: float) -> void:
	velocity = PlayerRegistry.move_vector(device_id) * SPEED + _repulsion()
	move_and_slide()

func _repulsion() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("crew"):
		if other == self:
			continue
		var away: Vector2 = global_position - other.global_position
		var distance := away.length()
		if distance == 0.0 or distance >= REPULSION_RADIUS:
			continue
		push += away / distance * REPULSION_STRENGTH * (1.0 - distance / REPULSION_RADIUS)
	return push
