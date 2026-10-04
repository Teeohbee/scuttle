extends Station

@export var carryable_scene: PackedScene
@export var kind: Carryable.Kind = Carryable.Kind.POWDER
@export var hold_duration: float = 0.8

var _elapsed := 0.0
var _user: Node2D = null

func _physics_process(delta: float) -> void:
	var user := _occupant()
	if user != _user:
		_user = user
		_elapsed = 0.0
	if not user:
		return
	_elapsed += delta
	if _elapsed >= hold_duration:
		_elapsed = 0.0
		_hand_to(user)

# The first crew member in reach who is holding interact. Crew who are merely
# standing nearby must not block the one actually using the station.
func _occupant() -> Node2D:
	for crew in get_tree().get_nodes_in_group("crew"):
		if crew_is_near(crew) and PlayerRegistry.is_interact_pressed(crew.device_id):
			return crew
	return null

func claims_interact(crew) -> bool:
	return crew_is_near(crew)

func perform_interact(_crew: Node2D) -> void:
	pass

func _hand_to(crew) -> void:
	if _is_water_station_and_bucket_empty(crew):
		crew.held_item.set_kind(Carryable.Kind.BUCKET_WATER)
		return
	if crew.held_item:
		return
	var item : Carryable = carryable_scene.instantiate()
	get_parent().add_child(item)
	item.global_position = global_position
	item.set_kind(kind)
	item.pick_up(crew.hold_point)
	crew.held_item = item

func _is_water_station_and_bucket_empty(crew) -> bool:
	return (kind == Carryable.Kind.BUCKET_WATER
		and crew.held_item
		and crew.held_item.kind == Carryable.Kind.BUCKET_EMPTY)
