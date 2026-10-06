class_name FireHazard
extends Node2D

signal outbreak(cell: Vector2i)
signal fuse_lit
signal fuse_out

const SPREAD_INTERVAL := 3.0
const DOUSE_REACH := 20.0
const MAGAZINE_ROOM := 'magazine'
const DAMP_TIME := 20.0
# Seconds from the magazine catching to the ship going up. Every magazine
# cell must be out before it runs down; douse them all and it resets.
const FUSE_TIME := 10.0
# A bucket also douses the four cells around the one it lands on.
const SPLASH := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

@export var hull: TileMapLayer

var _burning: Dictionary = {}
var _damp: Dictionary = {}
# When each cell's patch may next spread. A patch goes by its earliest cell, so
# a fresh outbreak waits a full SPREAD_INTERVAL and two fires that meet keep
# the sooner clock.
var _next_spread: Dictionary = {}
var _fuse := Timer.new()

var interact_priority: int = 10

func _ready() -> void:
	add_to_group('stations')
	_fuse.one_shot = true
	_fuse.timeout.connect(func(): GameState.lose("The magazine blew up"))
	add_child(_fuse)

func _process(_delta: float) -> void:
	_spread()

func ignite_random() -> void:
	var candidates := _ignitable_cells()
	if candidates.is_empty():
		return
	var cell := candidates[randi() % candidates.size()]
	_ignite(cell)
	outbreak.emit(cell)

# Seconds until the magazine goes up, or -1 if it isn't burning.
func fuse_left() -> float:
	return -1.0 if _fuse.is_stopped() else _fuse.time_left

func burning_cells() -> Array:
	return _burning.keys()

func is_burning(cell: Vector2i) -> bool:
	return _burning.has(cell)

# Whether a bucket thrown from here would land on a fire.
func can_douse_from(pos: Vector2) -> bool:
	return _nearest_burning(pos) != Vector2i.MIN

func in_magazine(cell: Vector2i) -> bool:
	return _room_of(cell) == MAGAZINE_ROOM

func world_of(cell: Vector2i) -> Vector2:
	return _world_of(cell)

func claims_interact(crew) -> bool:
	if crew.held_item == null or crew.held_item.kind != Carryable.Kind.BUCKET_WATER:
		return false
	return _nearest_burning(crew.global_position) != Vector2i.MIN

func perform_interact(crew) -> void:
	var cell := _nearest_burning(crew.global_position)
	if cell == Vector2i.MIN:
		return
	_extinguish(cell)
	for offset in SPLASH:
		_extinguish(cell + offset)
	crew.held_item.set_kind(Carryable.Kind.BUCKET_EMPTY)

# Each separate fire - a connected patch of burning cells - lights one new cell
# every SPREAD_INTERVAL, however big it is. Per-cell spreading grew with the
# fire's edge, so a crew either caught it at once or lost it entirely; a fixed
# rate per fire lets them fall behind and claw it back.
func _spread() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _next_spread.values().any(func(due): return due <= now):
		return
	var seen := {}
	for cell in _burning.keys():
		if seen.has(cell):
			continue
		var patch := _patch_of(cell)
		var due := INF
		for c in patch:
			seen[c] = true
			due = minf(due, _next_spread[c])
		if now < due:
			continue
		for c in patch:
			_next_spread[c] = now + SPREAD_INTERVAL
		var catchable := {}
		for c in patch:
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor: Vector2i = c + offset
				if _burning.has(neighbor) or catchable.has(neighbor):
					continue
				if _damp.has(neighbor) and _damp[neighbor] > now:
					continue
				if not _flammable(neighbor):
					continue
				catchable[neighbor] = true
		if not catchable.is_empty():
			_ignite(catchable.keys().pick_random())

# The burning cells connected to this one, side by side.
func _patch_of(cell: Vector2i) -> Array[Vector2i]:
	var patch: Array[Vector2i] = [cell]
	var found := {cell: true}
	var i := 0
	while i < patch.size():
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = patch[i] + offset
			if _burning.has(neighbor) and not found.has(neighbor):
				found[neighbor] = true
				patch.append(neighbor)
		i += 1
	return patch

func _extinguish(cell: Vector2i) -> void:
	if not _burning.has(cell):
		return
	_damp[cell] = (Time.get_ticks_msec() / 1000.0) + DAMP_TIME
	_burning[cell].queue_free()
	_burning.erase(cell)
	_next_spread.erase(cell)
	if _room_of(cell) == MAGAZINE_ROOM and not _fuse.is_stopped() and not _magazine_burning():
		_fuse.stop()
		fuse_out.emit()

func _magazine_burning() -> bool:
	for cell in _burning.keys():
		if _room_of(cell) == MAGAZINE_ROOM:
			return true
	return false

func _nearest_burning(from: Vector2) -> Vector2i:
	var best := Vector2i.MIN
	var best_dist := DOUSE_REACH
	for cell in _burning.keys():
		var d := from.distance_to(_world_of(cell))
		if d <= best_dist:
			best = cell
			best_dist = d
	return best

func _ignite(cell: Vector2i) -> void:
	if _burning.has(cell):
		return
	var visual := ColorRect.new()
	visual.size = Vector2(16, 16)
	visual.color = Color(0.85, 0.25, 0.1)
	add_child(visual)
	visual.global_position = _world_of(cell) - Vector2(8,8)
	_burning[cell] = visual
	_next_spread[cell] = (Time.get_ticks_msec() / 1000.0) + SPREAD_INTERVAL

	if _room_of(cell) == MAGAZINE_ROOM and _fuse.is_stopped():
		_fuse.start(FUSE_TIME)
		fuse_lit.emit()

func _world_of(cell: Vector2i) -> Vector2:
	return hull.to_global(hull.map_to_local(cell))

func _ignitable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in hull.get_used_cells():
		if _room_of(cell) != "":
			cells.append(cell)
	return cells

# Any deck a crew member could stand on burns - rooms, doorways and the
# corridor between them - so fire left alone walks from room to room.
func _flammable(cell: Vector2i) -> bool:
	var data := hull.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) == 0

func _room_of(cell: Vector2i) -> String:
	var data := hull.get_cell_tile_data(cell)
	if data == null:
		return ""
	var room: String = data.get_custom_data("room")
	return room
