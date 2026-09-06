extends Node2D

const CREW_SCENE := preload("res://src/crew/crew.tscn")

const SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(168, 88), Vector2(168, 120), Vector2(200, 88),
	Vector2(200, 120), Vector2(296, 88), Vector2(296, 120),
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var roster := PlayerRegistry.players()
	for i in range(roster.size()):
		var player = roster[i]
		var crew := CREW_SCENE.instantiate()
		crew.device_id = player.device_id
		crew.accent = player.color
		add_child(crew)
		crew.position = SPAWN_POSITIONS[i % SPAWN_POSITIONS.size()]
