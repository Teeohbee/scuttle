class_name DeckDresser
extends RefCounted
# Dresses the Hull's wall tiles as things a ship keeps on deck, so the 3D deck has no walls (look book
# Volume V). It reads only the tiles, so it follows any change to the layout. Every wall tile forward
# of the quarterdeck is one of:
#   EDGE     beside a room's floor: a piece of that room's stores, facing into the room
#   DIVIDER  room floor on both opposite sides (drawn as a box for now)
#   BITT     meets only the passage: a stout post with a coil, filling the tile
#   NONE     touches no floor, so nobody can reach it: bare deck
# Everything is baked into one vertex-coloured mesh.

enum Kind { NONE, EDGE, DIVIDER, BITT }

const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

const DARK := Color("3a2216")
const MID := Color("6b4228")
const LIGHT := Color("9a6a40")
const CAP := Color("7a5032")
const RED := Color("8e2a1e")
const IRON := Color("2c2c32")
const BRASS := Color("c8962e")
const ROPE := Color("b89a6a")
const CANVAS := Color("d8ccaa")
const KEG := Color("4a2e1c")
const SACK := Color("b8a47a")
const BLACK := Color("1c1a18")

var _hull: TileMapLayer
var _quarterdeck_column: int
var _centre_of: Callable   # cell -> Vector3, its centre on the deck
var _pieces := {}          # cell -> {kind, room, facing}
var _mesh: ArrayMesh

func _init(hull: TileMapLayer, quarterdeck_column: int, centre_of: Callable) -> void:
	_hull = hull
	_quarterdeck_column = quarterdeck_column
	_centre_of = centre_of
	for cell in hull.get_used_cells():
		if _is_wall(cell) and not is_under_quarterdeck(cell):
			_pieces[cell] = _classify(cell)

func kind_of(cell: Vector2i) -> Kind:
	return _pieces.get(cell, {}).get("kind", Kind.NONE)

func room_of(cell: Vector2i) -> String:
	return _pieces.get(cell, {}).get("room", "")

func facing_of(cell: Vector2i) -> Vector2i:
	return _pieces.get(cell, {}).get("facing", Vector2i.ZERO)

func is_under_quarterdeck(cell: Vector2i) -> bool:
	return cell.x >= _quarterdeck_column

func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh

func _classify(cell: Vector2i) -> Dictionary:
	for d in [Vector2i.RIGHT, Vector2i.DOWN]:
		if _room(cell + d) != "" and _room(cell - d) != "":
			return {kind = Kind.DIVIDER}
	for d in SIDES:
		if _room(cell + d) != "":
			return {kind = Kind.EDGE, room = _room(cell + d), facing = d}
	if SIDES.any(func(d): return _is_floor(cell + d)):
		return {kind = Kind.BITT}
	return {kind = Kind.NONE}

func _is_wall(cell: Vector2i) -> bool:
	var data := _hull.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) > 0

func _is_floor(cell: Vector2i) -> bool:
	var data := _hull.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) == 0

func _room(cell: Vector2i) -> String:
	return _hull.get_cell_tile_data(cell).get_custom_data("room") if _is_floor(cell) else ""

func _build() -> ArrayMesh:
	var st := MeshKit.begin()
	for cell: Vector2i in _pieces:
		var piece: Dictionary = _pieces[cell]
		var at: Vector3 = _centre_of.call(cell)
		match piece.kind:
			Kind.EDGE:
				# local +z points into the room, +x runs along its edge
				var f: Vector2i = piece.facing
				var basis := Basis(Vector3.UP, atan2(f.x, f.y))
				_edge(st, piece.room, at, basis, cell.x + cell.y)
			Kind.DIVIDER:
				MeshKit.box(st, at + Vector3(0, 0.5, 0), Vector3(1, 1, 1), MID)
			Kind.BITT:
				_bitt(st, at)
	return MeshKit.commit(st)

# A room's stores along its edge, knee to waist high and filling most of the tile, so it still
# reads as something you can't walk through. `n` varies the stacks from tile to tile.
func _edge(st: SurfaceTool, room: String, at: Vector3, basis: Basis, n: int) -> void:
	var p := func(x: float, y: float, z: float) -> Vector3:
		return at + basis * Vector3(x, y, z)
	var lying := basis * Basis(Vector3.BACK, -PI / 2)   # a barrel's axis along the edge
	match room:
		"foreHoldPort", "foreHoldStarboard":   # gun rooms: a shot rack and a rope rail on stanchions
			MeshKit.box(st, p.call(0, 0.16, 0), Vector3(0.96, 0.32, 0.4), RED, basis)
			for k in [-1, 0, 1]:
				MeshKit.ball(st, p.call(k * 0.3, 0.42, 0), 0.1, IRON)
			MeshKit.box(st, p.call(-0.45, 0.47, 0.3), Vector3(0.06, 0.95, 0.06), DARK, basis)
			for y in [0.55, 0.9]:
				MeshKit.box(st, p.call(0, y, 0.3), Vector3(1.0, 0.04, 0.04), ROPE, basis)
		"magazine":   # powder kegs, two high
			MeshKit.box(st, p.call(0, 0.05, 0), Vector3(1.0, 0.1, 0.9), DARK, basis)
			for z in [-0.23, 0.23]:
				MeshKit.barrel(st, p.call(-0.46, 0.33, z), 0.23, 0.92, KEG, IRON, 8, lying)
			MeshKit.barrel(st, p.call(-0.46, 0.73, 0), 0.23, 0.92, KEG, IRON, 8, lying)
		"shotLocker":   # a bin brimming with shot
			MeshKit.box(st, p.call(0, 0.25, 0), Vector3(0.96, 0.5, 0.7), MID, basis)
			MeshKit.box(st, p.call(0, 0.52, 0), Vector3(1.0, 0.06, 0.74), DARK, basis)
			for a in 4:
				for b in 3:
					MeshKit.ball(st, p.call(-0.33 + a * 0.22, 0.6, -0.2 + b * 0.2), 0.1, IRON)
		"waterStore":   # a cask lying in chocks, with its tap
			for z in [-0.3, 0.3]:
				MeshKit.box(st, p.call(0, 0.07, z), Vector3(0.9, 0.14, 0.12), DARK, basis)
			MeshKit.barrel(st, p.call(-0.46, 0.38, 0), 0.36, 0.92, MID, IRON, 10, lying)
			MeshKit.box(st, p.call(0.49, 0.38, 0), Vector3(0.12, 0.06, 0.06), BRASS, basis)
		"pumpRoom":   # a rack of fire buckets
			MeshKit.box(st, p.call(0, 0.2, 0), Vector3(0.96, 0.4, 0.5), DARK, basis)
			for x in [-0.3, 0.0, 0.3]:
				MeshKit.lathe(st, p.call(x, 0.4, 0), PackedVector2Array([Vector2(0.11, 0), Vector2(0.13, 0.28)]), 10, RED)
				MeshKit.cylinder(st, p.call(x, 0.4, 0), 0.11, 0.02, 10, BLACK)
		"lumberStore":   # stacked timber and a spar
			for k in 6:
				MeshKit.box(st, p.call((k % 2) * 0.05, 0.04 + k * 0.075, -0.15 + ((k * 5) % 3 - 1) * 0.03),
					Vector3(1.0, 0.07, 0.24), LIGHT if k % 2 else CAP, basis * Basis(Vector3.UP, (k - 2.5) * 0.03))
			MeshKit.cylinder(st, p.call(-0.5, 0.11, 0.28), 0.11, 1.0, 8, LIGHT, lying)
			if n % 2:
				MeshKit.ball(st, p.call(0.1, 0.62, -0.1), 0.2, SACK)
		_:   # the holds, and any room without its own stores: crates under canvas
			MeshKit.box(st, p.call(0, 0.39, 0), Vector3(0.78, 0.78, 0.78), LIGHT, basis * Basis(Vector3.UP, (n % 3) * 0.08))
			if n % 2:
				MeshKit.box(st, p.call(0.05, 1.03, 0), Vector3(0.5, 0.5, 0.5), LIGHT, basis * Basis(Vector3.UP, 0.5))
			else:
				MeshKit.box(st, p.call(0, 0.84, 0), Vector3(0.9, 0.12, 0.85), CANVAS, basis)
			MeshKit.box(st, p.call(-0.2, 0.8, 0), Vector3(0.04, 0.04, 0.9), ROPE, basis)

# A bitt: a stout post on a block that fills the tile, with a coil of rope on top.
func _bitt(st: SurfaceTool, at: Vector3) -> void:
	MeshKit.box(st, at + Vector3(0, 0.22, 0), Vector3(0.84, 0.44, 0.84), MID)
	MeshKit.box(st, at + Vector3(0, 0.72, 0), Vector3(0.42, 0.56, 0.42), DARK)
	MeshKit.box(st, at + Vector3(0, 1.04, 0), Vector3(0.5, 0.08, 0.5), CAP)
	MeshKit.torus(st, at + Vector3(0, 1.12, 0), 0.16, 0.035, ROPE)
	MeshKit.torus(st, at + Vector3(0, 1.17, 0), 0.11, 0.035, ROPE)
