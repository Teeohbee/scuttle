class_name View3D
extends CanvasLayer
# Draws the deck in 3D, over the top of the 2D art. It only ever reads 2D state.
# 1 tile = 16 px = 1 m, so a 2D point (x, y) sits at (x / 16, 0, y / 16).

const PX_PER_M := 16.0
const WALL_HEIGHT := 1.0
const FLOOR_COLOR := Color(0.48, 0.34, 0.22)
const WALL_COLOR := Color(0.36, 0.23, 0.14)
const ROOM_COLORS := {
	"magazine": Color(0.49, 0.29, 0.23),
	"shotLocker": Color(0.44, 0.42, 0.40),
	"waterStore": Color(0.33, 0.41, 0.48),
	"pumpRoom": Color(0.34, 0.44, 0.35),
	"lumberStore": Color(0.54, 0.45, 0.27),
}

@export var hull: TileMapLayer

var _world: Node3D
var _wall_count := 0
var _floor_count := 0

func _ready() -> void:
	_world = Node3D.new()
	add_child(_world)
	_build_deck()

func wall_count() -> int:
	return _wall_count

func floor_count() -> int:
	return _floor_count

func to_3d(point: Vector2) -> Vector3:
	return Vector3(point.x / PX_PER_M, 0.0, point.y / PX_PER_M)

# One MultiMesh for the walls and one for the floor, built once from the Hull tiles:
# a tile with collision is a wall, and the rest are floor tinted by their room.
func _build_deck() -> void:
	var walls: Array[Transform3D] = []
	var floors: Array[Transform3D] = []
	var floor_colors: Array[Color] = []
	for cell in hull.get_used_cells():
		var data := hull.get_cell_tile_data(cell)
		var at := to_3d(hull.to_global(hull.map_to_local(cell)))
		if data.get_collision_polygons_count(0) > 0:
			walls.append(Transform3D(Basis(), at + Vector3(0, WALL_HEIGHT / 2.0, 0)))
		else:
			floors.append(Transform3D(Basis(), at))
			floor_colors.append(ROOM_COLORS.get(data.get_custom_data("room"), FLOOR_COLOR))
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(1, WALL_HEIGHT, 1)
	_world.add_child(_multimesh(wall_box, walls, [], WALL_COLOR))
	var tile := PlaneMesh.new()
	tile.size = Vector2(1, 1)
	_world.add_child(_multimesh(tile, floors, floor_colors, Color.WHITE))
	_wall_count = walls.size()
	_floor_count = floors.size()

func _multimesh(mesh: Mesh, at: Array[Transform3D], colors: Array[Color], tint: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = at.size()
	for i in at.size():
		mm.set_instance_transform(i, at[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = mm.use_colors
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	return node
