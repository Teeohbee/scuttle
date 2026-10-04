extends Node
# Playtest driver: bot crew fight fires through the real input actions.
#
#   godot --headless --path . res://_playtest/bots.tscn -- --scenario=magazine --crew=2 --delay=25
#   godot --path . res://_playtest/bots.tscn -- --battle --scenario=watch --crew=6 --cap=180
#
# --scenario  magazine | foreHoldPort | shotLocker | lumberStore | waterStore (any name with --battle)
# --crew      bot count (1-6)          --delay  seconds before bots respond
# --cap       seconds before giving up --battle let the enemy fire instead of lighting one room
# Results land in _playtest/results/ as JSON. TRACE=1 logs bot positions twice a second.

const OUT := "res://_playtest/results"
const DOOR_X := [80.0, 192.0, 304.0, 416.0]
const PORT_DOOR_Y := 72.0
const STAR_DOOR_Y := 136.0
const PORT_LANE := 88.0
const STAR_LANE := 120.0

var scenario := "magazine"
var crew_count := 2
var battle := false
var cap := 120.0
var delay := 0.0

var t := 0.0
var _deck
var _fire
var _butt
var _bots: Array = []
var _log_lines: Array = []
var stats := {"buckets": 0, "fills": 0, "peak": 0, "ignitions": 0, "magazine_hit": false, "out_at": -1.0, "burn_seconds": 0.0, "fires_lit": 0, "fires_out": 0}

class Bot:
	var dev: int
	var crew
	var state := "to_butt"
	var path: Array = []
	var goal := Vector2.INF
	var press_cooldown := 0.0
	var trip_start := 0.0
	var last_pos := Vector2.ZERO
	var stuck := 0.0
	var target_cell := Vector2i.MIN

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv = a.trim_prefix("--").split("=")
		match kv[0]:
			"scenario": scenario = kv[1]
			"crew": crew_count = int(kv[1])
			"battle": battle = true
			"cap": cap = float(kv[1])
			"delay": delay = float(kv[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GameState.invulnerable = true
	PlayerRegistry.reset()
	for i in crew_count:
		var dev := 20 + i
		for action in ["move_left", "move_right", "move_up", "move_down", "interact", "join"]:
			InputMap.add_action("%s_pad%d" % [action, dev], 0.0)
		PlayerRegistry.join(dev)
	_deck = load("res://src/ship/deck.tscn").instantiate()
	add_child(_deck)
	_fire = _deck.get_node("Fire")
	_butt = _deck.get_node("WaterButt")
	_fire.outbreak.connect(_on_outbreak)
	for c in get_tree().get_nodes_in_group("crew"):
		var b := Bot.new()
		b.dev = c.device_id
		b.crew = c
		b.last_pos = c.global_position
		_bots.append(b)
	if not battle:
		_deck.get_node("EnemyShip").get_node("Cadence").stop()
		var cell: Vector2i = {
			"waterStore": Vector2i(12, 10), "magazine": Vector2i(12, 2),
			"shotLocker": Vector2i(19, 2), "lumberStore": Vector2i(26, 10),
			"foreHoldPort": Vector2i(5, 2),
		}[scenario]
		get_tree().create_timer(1.0).timeout.connect(func(): _fire._ignite(cell); stats.fires_lit += 1; _log("lit %s %s" % [scenario, cell]))

func _log(m: String) -> void:
	_log_lines.append("[%6.2f] %s" % [t, m])

func _on_outbreak(cell: Vector2i) -> void:
	stats.ignitions += 1
	if _fire._room_of(cell) == "magazine":
		stats.magazine_hit = true
	if battle and _fire._burning.size() == 1:
		stats.fires_lit += 1

func _physics_process(delta: float) -> void:
	t += delta
	var n: int = _fire._burning.size()
	stats.peak = max(stats.peak, n)
	if n > 0:
		stats.burn_seconds += delta
	if not battle and t > 1.5 and n == 0 and stats.out_at < 0:
		stats.out_at = t
		_log("OUT")
		_finish()
		return
	if t >= cap:
		_finish()
		return
	if delay > 0.0 and t >= delay and not stats.has("burning_at_response"):
		stats["burning_at_response"] = n
	if OS.has_environment("TRACE") and int(t * 60) % 30 == 0:
		for tb in _bots:
			_log("trace %d %s %s n=%d" % [tb.dev, tb.state, tb.crew.global_position.round(), n])
	for b in _bots:
		if t < delay:
			_move(b, Vector2.ZERO)
			continue
		_drive(b, delta)

func _finish() -> void:
	set_physics_process(false)
	stats["scenario"] = scenario
	stats["crew"] = crew_count
	stats["delay"] = delay
	stats["battle"] = battle
	stats["end_t"] = t
	stats["end_burning"] = _fire._burning.size()
	stats["avg_cycle"] = 0.0
	for b in _bots:
		_log("bot %d %s at %s item=%s path=%s" % [b.dev, b.state, b.crew.global_position.round(), b.crew.held_item.kind if b.crew.held_item else "-", b.path])
	var f := FileAccess.open("%s/%s-%s-%d-d%d.json" % [ProjectSettings.globalize_path(OUT), "battle" if battle else "fire", scenario, crew_count, int(delay)], FileAccess.WRITE)
	f.store_string(JSON.stringify({"stats": stats, "log": _log_lines}, "  "))
	f.close()
	print(JSON.stringify(stats))
	get_tree().quit()

# --- navigation -------------------------------------------------------------

func _room_index(p: Vector2) -> int:
	var c := int(p.x / 16.0)
	if c >= 2 and c <= 7: return 0
	if c >= 9 and c <= 14: return 1
	if c >= 16 and c <= 21: return 2
	if c >= 23 and c <= 28: return 3
	return -1

func _band(p: Vector2) -> String:
	var r := int(p.y / 16.0)
	if r >= 1 and r <= 3: return "port"
	if r >= 9 and r <= 11: return "star"
	return "corridor"

func _same_room(a: Vector2, b: Vector2) -> bool:
	return _band(a) != "corridor" and _band(a) == _band(b) and _room_index(a) == _room_index(b)

func _path(a: Vector2, b: Vector2) -> Array:
	if _same_room(a, b):
		return [b]
	var pts := []
	var lane: float = PORT_LANE if _band(b) == "port" else STAR_LANE
	var x := a.x
	if _band(a) != "corridor":
		# Keep to a side: crew heading down use the right of the doorway, crew heading up the left.
		x = DOOR_X[_room_index(a)] + (7.0 if _band(a) == "port" else -7.0)
		var door_y: float = PORT_DOOR_Y if _band(a) == "port" else STAR_DOOR_Y
		pts.append(Vector2(x, a.y))
		pts.append(Vector2(x, door_y))
	pts.append(Vector2(x, lane))
	if _band(b) == "corridor":
		pts.append(b)
		return pts
	var bx: float = DOOR_X[_room_index(b)] + (-7.0 if _band(b) == "port" else 7.0)
	var b_door_y: float = PORT_DOOR_Y if _band(b) == "port" else STAR_DOOR_Y
	pts.append(Vector2(bx, lane))
	pts.append(Vector2(bx, b_door_y))
	pts.append(Vector2(bx, b.y))
	pts.append(b)
	return pts

func _set_goal(b: Bot, g: Vector2) -> void:
	if b.goal.distance_to(g) < 1.0 and not b.path.is_empty():
		return
	b.goal = g
	b.path = _path(b.crew.global_position, g)

func _steer(b: Bot, delta: float) -> bool:
	var pos: Vector2 = b.crew.global_position
	while not b.path.is_empty() and pos.distance_to(b.path[0]) < 4.0:
		b.path.pop_front()
	if b.path.is_empty():
		_move(b, Vector2.ZERO)
		return true
	var dir: Vector2 = (b.path[0] - pos).normalized()
	if pos.distance_to(b.last_pos) < 0.2:
		b.stuck += delta
	else:
		b.stuck = 0.0
	b.last_pos = pos
	if b.stuck > 0.6:
		dir = dir.rotated(randf_range(-1.4, 1.4))
		if b.stuck > 1.5:
			b.path = _path(pos, b.goal)
			b.stuck = 0.0
	_move(b, dir)
	return false

func _move(b: Bot, dir: Vector2) -> void:
	var s := "pad%d" % b.dev
	_axis("move_right_" + s, max(dir.x, 0.0))
	_axis("move_left_" + s, max(-dir.x, 0.0))
	_axis("move_down_" + s, max(dir.y, 0.0))
	_axis("move_up_" + s, max(-dir.y, 0.0))

func _axis(action: String, v: float) -> void:
	if v > 0.01:
		Input.action_press(action, v)
	else:
		Input.action_release(action)

# --- behaviour ----------------------------------------------------------------

func _target_cell(b: Bot) -> Vector2i:
	var pos: Vector2 = b.crew.global_position
	var best := Vector2i.MIN
	var best_d := INF
	for cell in _fire._burning.keys():
		var d := pos.distance_to(_fire._world_of(cell))
		if d < best_d:
			best_d = d
			best = cell
	return best

func _drive(b: Bot, delta: float) -> void:
	var inter := "interact_pad%d" % b.dev
	var item = b.crew.held_item
	var full: bool = item != null and item.kind == Carryable.Kind.BUCKET_WATER
	b.press_cooldown -= delta
	if Input.is_action_pressed(inter) and b.state != "filling":
		Input.action_release(inter)
	if not full and b.state != "filling":
		for o in _bots:
			if o == b or o.crew.held_item == null or o.crew.held_item.kind != Carryable.Kind.BUCKET_WATER:
				continue
			var away: Vector2 = b.crew.global_position - o.crew.global_position
			if away.length() < 22.0:
				_move(b, away.normalized())
				return
	if not full:
		var butt_pos: Vector2 = _butt.global_position
		if b.state != "to_butt" and b.state != "filling":
			b.state = "to_butt"
			b.trip_start = t
		if b.crew.global_position.distance_to(butt_pos) <= 12.0:
			_move(b, Vector2.ZERO)
			if b.state != "filling":
				b.state = "filling"
				Input.action_press(inter)
		else:
			if b.state == "filling":
				Input.action_release(inter)
				b.state = "to_butt"
			_set_goal(b, butt_pos)
			_steer(b, delta)
		return
	if b.state == "filling":
		Input.action_release(inter)
		stats.fills += 1
		b.state = "to_fire"
	if not _fire._burning.has(b.target_cell):
		b.target_cell = _target_cell(b)
	var cell: Vector2i = b.target_cell
	if cell == Vector2i.MIN:
		b.state = "idle"
		_move(b, Vector2.ZERO)
		return
	b.state = "to_fire"
	var target: Vector2 = _fire._world_of(cell)
	var pos: Vector2 = b.crew.global_position
	if _fire._nearest_burning(pos) != Vector2i.MIN and b.press_cooldown <= 0.0:
		_move(b, Vector2.ZERO)
		Input.action_press(inter)
		b.press_cooldown = 0.2
		stats.buckets += 1
		return
	_set_goal(b, target)
	_steer(b, delta)
