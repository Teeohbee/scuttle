extends CharacterBody2D

const SPEED := 90

func _physics_process(delta: float) -> void:
	var move := Vector2.ZERO
	move.x = int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
	move.y = int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
	velocity = move.normalized() * SPEED
	move_and_slide()
