class_name Station
extends Area2D

var disabled := false
@export var breachable := true

var interact_priority := 0

@onready var _reach_shape: CircleShape2D = $CollisionShape2D.shape

func crew_is_near(crew: Node2D) -> bool:
	return not disabled and global_position.distance_to(crew.global_position) <= _reach_shape.radius

func claims_interact(_crew: Node2D) -> bool:
	return false

func perform_interact(_crew: Node2D) -> void:
	pass
