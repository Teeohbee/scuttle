extends CharacterBody2D

const SPEED := 90.0
const PICKUP_RANGE := 14.0

@export var device_id: int = PlayerRegistry.KEYBOARD_WASD
@export var accent: Color = Color.WHITE

var held_item: Carryable = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var hold_point: Marker2D = $HoldPoint

func _ready() -> void:
	add_to_group("crew")
	_sprite.modulate = accent

func _physics_process(_delta: float) -> void:
	velocity = PlayerRegistry.move_vector(device_id) * SPEED
	move_and_slide()
	_handle_interact()

func _handle_interact() -> void:
	if not PlayerRegistry.is_interact_just_pressed(device_id):
		return
	var winner: Node = null
	var best := -1
	for station in get_tree().get_nodes_in_group("stations"):
		if not station.claims_interact(self):
			continue
		if station.interact_priority > best:
			best = station.interact_priority
			winner = station
	if winner:
		winner.perform_interact(self)
		return
	_pick_up_or_drop()

func _pick_up_or_drop() -> void:
	if held_item:
		held_item.drop(get_parent(), global_position)
		held_item = null
		return
	var nearest := _nearest_loose_item()
	if nearest:
		nearest.pick_up(hold_point)
		held_item = nearest

func _nearest_loose_item() -> Carryable:
	var best: Carryable = null
	var best_distance := PICKUP_RANGE
	for item in get_tree().get_nodes_in_group("carryables"):
		if item.held:
			continue
		var distance := global_position.distance_to(item.global_position)
		if distance <= best_distance:
			best = item
			best_distance = distance
	return best
