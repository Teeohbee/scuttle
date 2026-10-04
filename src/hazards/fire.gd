class_name FireHazard
extends Node2D

signal outbreak(cell: Vector2i)

const SPREAD_INTERVAL := 3.0
const DOUSE_REACH := 20.0
const MAGAZINE_ROOM := 'magazine'

@export var hull: TileMapLayer

var _burning: Dictionary = {}
var _elapsed := 0.0
var _reported_magazine := false

var interact_priority: int = 10

func _ready() -> void:
	add_to_group('stations')

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < SPREAD_INTERVAL:
		return
	_elapsed = 0.0
	_spread()
	pass

func ignite_random() -> void:
	var candidates := _ignitable_cells()
	if candidates.is_empty():
		return
	_ignite(candidates[randi() % candidates.size()])

func claims_interact(crew) -> bool:
	if crew.held_item == null or crew.held_item.kind != Carryable.Kind.BUCKET_WATER:
		return false
	return _nearest_burning(crew.global_position) != Vector2i.MIN

func perform_interact(crew) -> void:
	var cell := _nearest_burning(crew.global_position)
	if cell == Vector2i.MIN:
		return
	_extinguish(cell)
	crew.held_item.set_kind(Carryable.Kind.BUCKET_EMPTY)

func _spread() -> void:
	var frontier: Array = _burning.keys()
	for cell in frontier:
		var room := _room_of(cell)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = cell + offset
			if _burning.has(neighbor):
				continue
			if _room_of(neighbor) != room:
				continue
			_ignite(neighbor)

func _extinguish(cell: Vector2i) -> void:
	if not _burning.has(cell):
		return
	_burning[cell].queue_free()
	_burning.erase(cell)

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
	outbreak.emit(cell)
	
	if _room_of(cell) == MAGAZINE_ROOM and not _reported_magazine:
		_reported_magazine = true
		GameState.lose("The magazine caught fire")

func _world_of(cell: Vector2i) -> Vector2:
	return hull.to_global(hull.map_to_local(cell))

func _ignitable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in hull.get_used_cells():
		if _room_of(cell) != "":
			cells.append(cell)
	return cells

func _room_of(cell: Vector2i) -> String:
	var data := hull.get_cell_tile_data(cell)
	if data == null:
		return ""
	var room: String = data.get_custom_data("room")
	return room
