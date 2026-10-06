extends Station

@export var carryable_scene: PackedScene
@export var kind: Carryable.Kind = Carryable.Kind.POWDER
@export var hold_duration: float = 0.8

const BAR_SIZE := Vector2(16, 2)
const BAR_OFFSET := Vector2(-8, -12)

var _elapsed := 0.0
var _user: Node2D = null
# Drawn on its own node so it sits above the crew standing at the station.
var _bar := Node2D.new()

func _ready() -> void:
	_bar.z_index = 10
	_bar.draw.connect(_draw_bar)
	add_child(_bar)

func _physics_process(delta: float) -> void:
	var user := _occupant()
	if user != _user:
		_user = user
		_elapsed = 0.0
	_bar.queue_redraw()
	if not user or not _would_give(user):
		_elapsed = 0.0
		return
	_elapsed += delta
	if _elapsed >= hold_duration:
		_elapsed = 0.0
		_hand_to(user)

func _draw_bar() -> void:
	if _elapsed <= 0.0:
		return
	_bar.draw_rect(Rect2(BAR_OFFSET, BAR_SIZE), Color(0, 0, 0, 0.6))
	var fill := Vector2(BAR_SIZE.x * minf(_elapsed / hold_duration, 1.0), BAR_SIZE.y)
	_bar.draw_rect(Rect2(BAR_OFFSET, fill), Color.WHITE)

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

# Whether holding here would get this crew member anything - so a full pair
# of hands doesn't fill the bar over and over for nothing.
func _would_give(crew) -> bool:
	return crew.held_item == null or _is_water_station_and_bucket_empty(crew)

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
