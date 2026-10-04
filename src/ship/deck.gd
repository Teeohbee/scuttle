extends Node2D

const CREW_SCENE := preload("res://src/crew/crew.tscn")

@onready var _hull: TileMapLayer = $Hull
@onready var _enemy: EnemyShip = $EnemyShip

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
	_enemy.broadside_landed.connect(_on_broadside_landed)
	for cannon in get_tree().get_nodes_in_group("cannons"):
		cannon.fired.connect(_on_cannon_fired)
	$Fire.outbreak.connect(func(cell): $Feed.push("Fire in %s!" % _room_name(cell)))
	_enemy.fired.connect(func(): $Feed.push("The enemy fired!"))

func _room_name(cell: Vector2i) -> String:
	var data := _hull.get_cell_tile_data(cell)
	if data:
		var room: String = data.get_custom_data("room")
		if room != "":
			return room.capitalize()
	return "the ship"

func _on_cannon_fired(damage: float) -> void:
	_enemy.take_damage(damage)

func _on_broadside_landed() -> void:
	match randi() % 3:
		0: $Fire.ignite_random()
		1: return
		2: return
