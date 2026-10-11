class_name View3D
extends CanvasLayer
# Draws the deck in 3D, over the top of the 2D art. It only ever reads 2D state.
# 1 tile = 16 px = 1 m, so a 2D point (x, y) sits at (x / 16, 0, y / 16).
#
# The switch (toggle_view): crossfade with the camera looking straight down through a narrow
# lens from far away, which lines up with the 2D tile for tile, then tilt and widen to the game
# angle. In 2D the 3D isn't drawn and doesn't process.

const PX_PER_M := 16.0
const SWITCH_TIME := 1.2
const FADE_SHARE := 0.3          # first 30% of the switch is the crossfade
const FLAT_FOV := 10.0           # horizontal, degrees: narrow enough to look flat
const GAME_FOV := 50.0
const GAME_TILT := deg_to_rad(31.0)
const WALL_HEIGHT := 1.0
const FLOOR_COLOR := Color(0.48, 0.34, 0.22)
const HULL_COLOR := Color(0.29, 0.17, 0.11)
const HULL_DEPTH := 2.2
const BULWARK_HEIGHT := 0.9
const BULWARK_COLOR := Color(0.42, 0.27, 0.16)
const BULWARK_PAINT := Color(0.6, 0.16, 0.12)   # inboard face
const RAIL_COLOR := Color(0.3, 0.19, 0.11)
const WALL_COLOR := Color(0.36, 0.23, 0.14)
const ROOM_COLORS := {
	"magazine": Color(0.49, 0.29, 0.23),
	"shotLocker": Color(0.44, 0.42, 0.40),
	"waterStore": Color(0.33, 0.41, 0.48),
	"pumpRoom": Color(0.34, 0.44, 0.35),
	"lumberStore": Color(0.54, 0.45, 0.27),
}

const STATION_COLORS := {
	"cannon": Color(0.18, 0.18, 0.2),
	"magazine": Color(0.45, 0.16, 0.12),
	"shot_locker": Color(0.25, 0.25, 0.28),
	"water_butt": Color(0.3, 0.55, 0.8),
	"pump": Color(0.4, 0.4, 0.42),
	"lumber_crate": Color(0.62, 0.45, 0.26),
}
const ITEM_COLORS := {
	Carryable.Kind.POWDER: Color(0.45, 0.2, 0.15),
	Carryable.Kind.SHOT: Color(0.15, 0.15, 0.17),
	Carryable.Kind.PLANK: Color(0.72, 0.54, 0.31),
	Carryable.Kind.BUCKET_WATER: Color(0.35, 0.65, 0.88),
	Carryable.Kind.BUCKET_EMPTY: Color(0.5, 0.4, 0.3),
}

@export var hull: TileMapLayer
@export var fire: FireHazard
@export var enemy: Node2D
@export var camera_2d: Camera2D

var is_3d := false
var _blend := 0.0                # 0 = 2D, 1 = 3D at the game angle
var _tween: Tween
var _container: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _world: Node3D
var _outline: PackedVector2Array   # the hull's edge at deck level, (x, z) in metres
var _plank_texture: ImageTexture
var _gaps := PackedVector2Array()   # gun ports in the bulwark, (x, z) in metres
var _wall_count := 0
var _floor_count := 0
var _mirrors := {}   # 2D node -> its 3D stand-in
var _flames: Array[MeshInstance3D] = []

func _ready() -> void:
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_container.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_build_stage()
	_build_hull()
	_build_bulwark()
	_build_deck()
	_sleep()

func _process(_delta: float) -> void:
	_sync()
	pose(_blend)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view"):
		toggle()

func toggle() -> void:
	set_3d(not is_3d)

func set_3d(on: bool, animate := true) -> void:
	is_3d = on
	if _tween:
		_tween.kill()
	if on:
		_wake()
	var goal := 1.0 if on else 0.0
	if not animate:
		_apply(goal)
		if not on:
			_sleep()
		return
	_tween = create_tween()
	_tween.tween_method(_apply, _blend, goal, SWITCH_TIME * absf(goal - _blend))
	if not on:
		_tween.tween_callback(_sleep)

func blend() -> float:
	return _blend

func opacity() -> float:
	return _container.modulate.a

func camera() -> Camera3D:
	return _camera

func camera_tilt() -> float:
	return Vector3.UP.angle_to(_camera.position - _target())

func is_drawing() -> bool:
	return _container.visible and _viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED

# Place the camera for a point in the switch. The narrow lens is pulled back so the deck
# always spans the same width as the 2D view (a dolly zoom).
func pose(b: float) -> void:
	var e := _smooth((b - FADE_SHARE) / (1.0 - FADE_SHARE))
	var fov := lerpf(FLAT_FOV, GAME_FOV, e)
	var tilt := lerpf(0.0, GAME_TILT, e)
	var half_width := get_viewport().get_visible_rect().size.x / 2.0 / PX_PER_M / camera_2d.zoom.x
	var distance := half_width / tan(deg_to_rad(fov) / 2.0)
	_camera.fov = fov
	_camera.near = maxf(0.05, distance - 30.0)
	_camera.far = distance + 150.0
	_camera.position = _target() + Vector3(0, distance * cos(tilt), distance * sin(tilt))
	_camera.look_at(_target(), Vector3.FORWARD)

func _apply(b: float) -> void:
	_blend = b
	_container.modulate.a = _smooth(b / FADE_SHARE)
	pose(b)

func _wake() -> void:
	# Fade and pose before showing: the tween's first tick is a frame away.
	_sync()
	_apply(_blend)
	_container.visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)

func _sleep() -> void:
	_container.visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)

func _target() -> Vector3:
	return to_3d(camera_2d.get_screen_center_position())

func _smooth(x: float) -> float:
	return smoothstep(0.0, 1.0, x)

# Camera, sun, sky colour and the sea.
func _build_stage() -> void:
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_world.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-30), 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	_world.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.25, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)
	var sea := PlaneMesh.new()
	sea.size = Vector2(400, 400)
	_world.add_child(_mesh(sea, Vector3(0, -0.8, 0), Color(0.12, 0.33, 0.48)))

func mirror_of(node: Node) -> Node3D:
	return _mirrors.get(node)

func lamp_color(station: Node) -> Color:
	var lamp: MeshInstance3D = _mirrors[station].get_node_or_null("Lamp")
	return lamp.material_override.albedo_color if lamp else Color.BLACK

func flame_count() -> int:
	return _flames.filter(func(f): return f.visible).size()

func has_flame_at(point: Vector3) -> bool:
	return _flames.any(func(f): return f.visible and Vector2(f.position.x, f.position.z).distance_to(Vector2(point.x, point.z)) < 0.1)

func hull_outline() -> PackedVector2Array:
	return _outline

func bulwark_gaps() -> PackedVector2Array:
	return _gaps

func wall_count() -> int:
	return _wall_count

func floor_count() -> int:
	return _floor_count

func to_3d(point: Vector2) -> Vector3:
	return Vector3(point.x / PX_PER_M, 0.0, point.y / PX_PER_M)

# The hull, from the tiles' bounding box: straight sides, rounded stern corners and a bow that runs
# forward of the first column. The deck is its top, planked out to the edge.
func _build_hull() -> void:
	var r := _deck_rect()
	var fore := r.position.x - 0.4
	var aft := r.end.x + 0.3
	var port := r.position.y - 0.35
	var starboard := r.end.y + 0.35
	var mid := r.get_center().y
	_outline = PackedVector2Array([Vector2(fore + 2.0, port), Vector2(aft - 0.6, port)])
	_outline += _curve(Vector2(aft - 0.6, port), Vector2(aft, port), Vector2(aft, port + 0.6))
	_outline.append(Vector2(aft, starboard - 0.6))
	_outline += _curve(Vector2(aft, starboard - 0.6), Vector2(aft, starboard), Vector2(aft - 0.6, starboard))
	_outline.append(Vector2(fore + 2.0, starboard))
	_outline += _curve(Vector2(fore + 2.0, starboard), Vector2(fore - 1.6, starboard), Vector2(fore - 3.2, mid))
	_outline += _curve(Vector2(fore - 3.2, mid), Vector2(fore - 1.6, port), Vector2(fore + 2.0, port))
	_outline.remove_at(_outline.size() - 1)   # the bow curve ends where the outline started
	var deck := _plank_material(FLOOR_COLOR)
	var sides := StandardMaterial3D.new()
	sides.albedo_color = HULL_COLOR
	_world.add_child(_slab(_outline, -HULL_DEPTH, -0.02, sides, deck))

# A waist-high rail round the hull's edge, painted red inboard, with a port cut for each gun.
# It's built from short pieces so the bow curves and a port is a missing piece.
func _build_bulwark() -> void:
	var r := _deck_rect()
	var mid := r.get_center().y
	var guns: Array[Vector2] = []
	for s in get_tree().get_nodes_in_group("stations"):
		if "phase" in s:
			var at := to_3d(s.global_position)
			guns.append(Vector2(at.x, at.z))
	var centre := r.get_center()
	var body: Array[Transform3D] = []
	var paint: Array[Transform3D] = []
	var rail: Array[Transform3D] = []
	var sills: Array[Transform3D] = []
	for i in _outline.size():
		var a := _outline[i]
		var b := _outline[(i + 1) % _outline.size()]
		var pieces := ceili(a.distance_to(b) / 0.5)
		for k in pieces:
			var p := a.lerp(b, float(k) / pieces)
			var q := a.lerp(b, float(k + 1) / pieces)
			var m := (p + q) / 2.0
			var inboard := Vector2(q.y - p.y, p.x - q.x).normalized()
			if inboard.dot(centre - m) < 0.0:
				inboard = -inboard
			var along := Basis(Vector3.UP, atan2(p.y - q.y, q.x - p.x))
			var length := p.distance_to(q) + 0.02
			var at := func(offset: float, y: float) -> Vector3:
				var c := m + inboard * offset
				return Vector3(c.x, y, c.y)
			var on_straight := absf(m.y - mid) > r.size.y / 2.0
			if on_straight and guns.any(func(g): return signf(g.y - mid) == signf(m.y - mid) and absf(g.x - m.x) < 0.5):
				_gaps.append(m)
				sills.append(Transform3D(along * Basis.from_scale(Vector3(length, 0.2, 0.24)), at.call(0.1, 0.1)))
				continue
			body.append(Transform3D(along * Basis.from_scale(Vector3(length, BULWARK_HEIGHT, 0.2)), at.call(0.1, BULWARK_HEIGHT / 2.0)))
			paint.append(Transform3D(along * Basis.from_scale(Vector3(length, BULWARK_HEIGHT - 0.12, 0.02)), at.call(0.21, BULWARK_HEIGHT / 2.0 - 0.02)))
			rail.append(Transform3D(along * Basis.from_scale(Vector3(length + 0.02, 0.07, 0.3)), at.call(0.1, BULWARK_HEIGHT + 0.035)))
	var unit := BoxMesh.new()
	_world.add_child(_multimesh(unit, body, [], BULWARK_COLOR))
	_world.add_child(_multimesh(unit, paint, [], BULWARK_PAINT))
	_world.add_child(_multimesh(unit, rail, [], RAIL_COLOR))
	_world.add_child(_multimesh(unit, sills, [], RAIL_COLOR))

# The used tiles' bounding box on the deck, (x, z) in metres.
func _deck_rect() -> Rect2:
	var used := hull.get_used_rect()
	var half := Vector2(hull.tile_set.tile_size) / 2.0
	var a := to_3d(hull.to_global(hull.map_to_local(used.position) - half))
	var b := to_3d(hull.to_global(hull.map_to_local(used.end - Vector2i.ONE) + half))
	return Rect2(a.x, a.z, b.x - a.x, b.z - a.z)

# Points along a quadratic curve from a to b pulled towards control, not including a.
func _curve(a: Vector2, control: Vector2, b: Vector2, steps := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, steps + 1):
		var t := float(i) / steps
		out.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return out

# A flat-topped prism: the outline extruded from bottom to top. Normals are set by hand and
# culling is off, so the outline can wind either way.
func _slab(outline: PackedVector2Array, bottom: float, top: float, sides: Material, cap: Material) -> MeshInstance3D:
	var centre := Vector2.ZERO
	for p in outline:
		centre += p / outline.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var n := Vector2(b.y - a.y, a.x - b.x).normalized()
		if n.dot((a + b) / 2.0 - centre) < 0.0:
			n = -n
		st.set_normal(Vector3(n.x, 0, n.y))
		for v in [Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), Vector3(b.x, top, b.y),
				Vector3(a.x, bottom, a.y), Vector3(b.x, top, b.y), Vector3(a.x, top, a.y)]:
			st.add_vertex(v)
	var mesh := st.commit()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in Geometry2D.triangulate_polygon(outline):
		st.add_vertex(Vector3(outline[i].x, top, outline[i].y))
	st.commit(mesh)
	for m in [sides, cap]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.set_surface_override_material(0, sides)
	node.set_surface_override_material(1, cap)
	return node

# Planks run fore and aft, four to the metre, mapped in world space so every surface lines up.
func _plank_material(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = _planks()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	return m

func _planks() -> ImageTexture:
	if _plank_texture:
		return _plank_texture
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for row in 4:
		var shade := 0.88 + 0.04 * (row * 7 % 4)
		img.fill_rect(Rect2i(0, row * 16, 64, 16), Color(shade, shade, shade))
		img.fill_rect(Rect2i(0, row * 16 + 15, 64, 1), Color(0.45, 0.45, 0.45))     # seam
		img.fill_rect(Rect2i((row * 37) % 60, row * 16, 2, 15), Color(0.55, 0.55, 0.55))   # butt joint
	img.generate_mipmaps()
	_plank_texture = ImageTexture.create_from_image(img)
	return _plank_texture

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
	var floor := _multimesh(tile, floors, floor_colors, Color.WHITE)
	floor.material_override = _plank_material(Color.WHITE)
	floor.material_override.vertex_color_use_as_albedo = true
	floor.material_override.vertex_color_is_srgb = true
	_world.add_child(floor)
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
	material.vertex_color_is_srgb = true   # instance colours are written as sRGB, like albedo
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	return node

# Every frame: make sure each crew member, station, item and the enemy has a stand-in, move them all
# to match, and drop stand-ins whose 2D node has gone.
func _sync() -> void:
	for node in _mirrors.keys():
		if not is_instance_valid(node):
			_mirrors[node].queue_free()
			_mirrors.erase(node)
	for c in get_tree().get_nodes_in_group("crew"):
		_place(c, func(): return _crew_mirror(c.accent))
	for s in get_tree().get_nodes_in_group("stations"):
		if s is Station:
			var m := _place(s, func(): return _station_mirror(s))
			if "phase" in s:   # cannons: the lamp is how players read what a gun needs next
				var lamp: StandardMaterial3D = m.get_node("Lamp").material_override
				lamp.albedo_color = s.PHASE_COLORS[s.phase]
				lamp.emission = lamp.albedo_color
	for item in get_tree().get_nodes_in_group("carryables"):
		var m := _place(item, func(): return _box(Vector3(0.3, 0.3, 0.3), Color.WHITE))
		m.position.y = 1.3 if item.held else 0.0
		(m.get_child(0) as MeshInstance3D).material_override.albedo_color = ITEM_COLORS.get(item.kind, Color.WHITE)
	if enemy:
		_place(enemy, func(): return _box(Vector3(16, 1.6, 4), Color(0.17, 0.1, 0.07)))
	_sync_flames()

func _place(node: Node2D, make: Callable) -> Node3D:
	var m: Node3D = _mirrors.get(node)
	if m == null:
		m = make.call()
		_world.add_child(m)
		_mirrors[node] = m
	var at := to_3d(node.global_position)
	m.position.x = at.x
	m.position.z = at.z
	return m

func _sync_flames() -> void:
	var cells: Array = fire.burning_cells() if fire else []
	while _flames.size() < cells.size():
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.35
		cone.height = 0.8
		var flame := MeshInstance3D.new()
		flame.mesh = cone
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.55, 0.15)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.45, 0.1)
		glow.emission_energy_multiplier = 2.0
		flame.material_override = glow
		_world.add_child(flame)
		_flames.append(flame)
	for i in _flames.size():
		_flames[i].visible = i < cells.size()
		if _flames[i].visible:
			_flames[i].position = to_3d(fire.world_of(cells[i])) + Vector3(0, 0.4, 0)

func _station_color(station: Node) -> Color:
	return STATION_COLORS.get(station.scene_file_path.get_file().get_basename(), Color.GRAY)

func _station_mirror(station: Node) -> Node3D:
	var root := _box(Vector3(0.8, 0.6, 0.8), _station_color(station))
	if "phase" in station:
		var cube := BoxMesh.new()
		cube.size = Vector3(0.3, 0.12, 0.3)
		var lamp := _mesh(cube, Vector3(0, 0.66, 0), Color.GRAY)
		lamp.name = "Lamp"
		lamp.material_override.emission_enabled = true
		lamp.material_override.emission_energy_multiplier = 1.5
		root.add_child(lamp)
	return root

func _crew_mirror(accent: Color) -> Node3D:
	var root := Node3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.28
	body.height = 0.9
	root.add_child(_mesh(body, Vector3(0, 0.45, 0), accent))
	return root

func _box(size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	var box := BoxMesh.new()
	box.size = size
	root.add_child(_mesh(box, Vector3(0, size.y / 2.0, 0), color))
	return root

func _mesh(mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	m.material_override = material
	return m
