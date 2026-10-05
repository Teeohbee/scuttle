class_name BotPilot
extends Node
# Sits under a bot's crew node and plays it through the same Input Map actions a
# pad would press. Nothing else in the game knows it's a bot.

const ARRIVE_DISTANCE := 4.0
# No progress towards the next waypoint for this long means something is in the
# way: wiggle, then repath.
const STUCK_TIME := 0.6
const REPATH_TIME := 1.5
# Crew closer than this, roughly ahead, make a bot step to its own side - two bots
# meeting head on both step aside and pass, like the doorway lanes.
const GIVE_WAY_RANGE := 18.0

# Seconds between presses when throwing - a held button only throws once.
const THROW_COOLDOWN := 0.2
# Empty-handed crew step out of the way of anyone carrying water this close.
const CLEAR_WAY_RANGE := 22.0

var nav: DeckNav
var fire: FireHazard
var water_butt: Node2D
var home: Vector2

var _crew: CharacterBody2D
var _suffix: String
var _path: Array[Vector2] = []
var _goal := Vector2.INF
var _last_gap := INF
var _stuck := 0.0
var _target_cell := Vector2i.MIN
var _throw_cooldown := 0.0

func _ready() -> void:
	_crew = get_parent()
	_suffix = PlayerRegistry.suffix(_crew.device_id)
	# Press before the crew reads its input this frame, or every "just pressed"
	# lands a frame late and is missed.
	process_physics_priority = -1

func _physics_process(delta: float) -> void:
	_throw_cooldown -= delta
	_fight_fire(delta)

# --- behaviour ------------------------------------------------------------

# Fill a bucket at the water butt, carry it to the nearest fire, throw, repeat.
# With nothing burning, go home and wait.
func _fight_fire(delta: float) -> void:
	var item: Carryable = _crew.held_item
	var full := item != null and item.kind == Carryable.Kind.BUCKET_WATER
	var at_butt := _crew.global_position.distance_to(water_butt.global_position) <= 12.0
	if not full and is_holding_interact() and not at_butt:
		hold_interact(false)
	if fire.burning_cells().is_empty():
		hold_interact(false)
		go_to(home, delta)
		return
	if not full:
		if _clear_way():
			return
		if go_to(water_butt.global_position, delta) or at_butt:
			stop()
			hold_interact(true)
		return
	if is_holding_interact():
		hold_interact(false)
		return
	if not fire.is_burning(_target_cell):
		_target_cell = _nearest_fire()
	if fire.can_douse_from(_crew.global_position):
		stop()
		if _throw_cooldown <= 0.0:
			hold_interact(true)
			_throw_cooldown = THROW_COOLDOWN
		return
	go_to(fire.world_of(_target_cell), delta)

func _nearest_fire() -> Vector2i:
	var best := Vector2i.MIN
	var best_d := INF
	for cell in fire.burning_cells():
		var d := _crew.global_position.distance_to(fire.world_of(cell))
		if d < best_d:
			best = cell
			best_d = d
	return best

# Step away from crew carrying water, so the butt doesn't silt up with people
# queueing and the full buckets can get out.
func _clear_way() -> bool:
	for other in get_tree().get_nodes_in_group("crew"):
		if other == _crew or other.held_item == null or other.held_item.kind != Carryable.Kind.BUCKET_WATER:
			continue
		var away: Vector2 = _crew.global_position - other.global_position
		if away.length() < CLEAR_WAY_RANGE:
			hold_interact(false)
			steer(away.normalized())
			return true
	return false

# --- movement -------------------------------------------------------------

# Walk towards `goal`. True once standing on it.
func go_to(goal: Vector2, delta: float) -> bool:
	var pos := _crew.global_position
	if _goal.distance_to(goal) > 1.0 or _path.is_empty():
		_goal = goal
		_path = nav.path(pos, goal)
	while not _path.is_empty() and pos.distance_to(_path[0]) < ARRIVE_DISTANCE:
		_path.pop_front()
	if _path.is_empty():
		stop()
		return pos.distance_to(goal) < ARRIVE_DISTANCE * 2.0
	var dir := (_path[0] - pos).normalized()
	var gap := pos.distance_to(_path[0])
	_stuck = _stuck + delta if gap > _last_gap - 0.3 else 0.0
	_last_gap = gap
	dir = _give_way(dir)
	if _stuck > STUCK_TIME:
		dir = dir.rotated(randf_range(-1.4, 1.4))
		if _stuck > REPATH_TIME:
			_path = nav.path(pos, goal)
			_stuck = 0.0
			_last_gap = INF
	steer(dir)
	return false

func _give_way(dir: Vector2) -> Vector2:
	for other in get_tree().get_nodes_in_group("crew"):
		if other == _crew:
			continue
		var to_other: Vector2 = other.global_position - _crew.global_position
		if to_other.length() < GIVE_WAY_RANGE and dir.dot(to_other.normalized()) > 0.5:
			return (dir + dir.orthogonal()).normalized()
	return dir

func steer(dir: Vector2) -> void:
	_axis("move_right", max(dir.x, 0.0))
	_axis("move_left", max(-dir.x, 0.0))
	_axis("move_down", max(dir.y, 0.0))
	_axis("move_up", max(-dir.y, 0.0))

func stop() -> void:
	steer(Vector2.ZERO)

func hold_interact(held: bool) -> void:
	_axis("interact", 1.0 if held else 0.0)

func is_holding_interact() -> bool:
	return Input.is_action_pressed("interact_" + _suffix)

func _axis(action: String, strength: float) -> void:
	var name := "%s_%s" % [action, _suffix]
	if strength > 0.01:
		Input.action_press(name, strength)
	else:
		Input.action_release(name)
