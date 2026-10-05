class_name DeckNav
extends RefCounted
# Walkable grid for bots, read from the Hull tilemap: any tile with a collision
# polygon is wall, anything else is floor. Repaint the hull and the bots follow.

# Doorways are two tiles wide. Crew heading down take the right-hand tile and crew
# heading up the left, so two-way traffic passes instead of meeting head on.
const LANE_SHIFT := 8.0

var _hull: TileMapLayer
var _grid := AStarGrid2D.new()
var _doors := {}

func _init(hull: TileMapLayer) -> void:
	_hull = hull
	_grid.region = hull.get_used_rect()
	_grid.cell_size = hull.tile_set.tile_size
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for x in range(_grid.region.position.x, _grid.region.end.x):
		for y in range(_grid.region.position.y, _grid.region.end.y):
			if _is_wall(Vector2i(x, y)):
				_grid.set_point_solid(Vector2i(x, y))
	for cell in hull.get_used_cells():
		if not _is_wall(cell) and _room(cell) == "" and (_room(cell + Vector2i.UP) != "" or _room(cell + Vector2i.DOWN) != ""):
			_doors[cell] = true

# World-space waypoints from one point to another, ending exactly on `to`.
# Empty when there's no way through.
func path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a := cell_of(from)
	var b := cell_of(to)
	if not walkable(a) or not walkable(b):
		return out
	var cells := _grid.get_id_path(a, b)
	for i in range(1, cells.size()):
		var cell: Vector2i = cells[i]
		var p := world_of(cell)
		if _doors.has(cell):
			var before: Vector2i = cells[i - 1]
			var after: Vector2i = cells[i + 1] if i + 1 < cells.size() else b
			var going_down := after.y > before.y
			p.x = _door_centre_x(cell) + (LANE_SHIFT if going_down else -LANE_SHIFT)
		out.append(p)
	if out.is_empty() or out.back().distance_to(to) > 0.5:
		out.append(to)
	return out

func walkable(cell: Vector2i) -> bool:
	return _grid.is_in_boundsv(cell) and not _grid.is_point_solid(cell)

func cell_of(p: Vector2) -> Vector2i:
	return _hull.local_to_map(_hull.to_local(p))

func world_of(cell: Vector2i) -> Vector2:
	return _hull.to_global(_hull.map_to_local(cell))

func _door_centre_x(cell: Vector2i) -> float:
	var other := cell + (Vector2i.RIGHT if _doors.has(cell + Vector2i.RIGHT) else Vector2i.LEFT)
	return (world_of(cell).x + world_of(other).x) / 2.0

func _is_wall(cell: Vector2i) -> bool:
	var data := _hull.get_cell_tile_data(cell)
	return data == null or data.get_collision_polygons_count(0) > 0

func _room(cell: Vector2i) -> String:
	var data := _hull.get_cell_tile_data(cell)
	return data.get_custom_data("room") if data else ""
