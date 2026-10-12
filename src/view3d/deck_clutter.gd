class_name DeckClutter
extends MeshInstance3D
# The odds and ends of a working deck that aren't any room's cargo. None of it stands on a tile you
# can walk on: what's solid sits on the rail or on wall tiles, so the 2D rule holds that what you
# can't walk through is what you can see. All of it is one mesh.

const HAMMOCK_RADIUS := 0.13
const HAMMOCK_LENGTH := 0.55
const HAMMOCK_GAP := 0.05
const RAIL_TOP := View3D.BULWARK_HEIGHT + 0.07
const BANANA := Color("e8c040")
const PUDDLE := Color(0.29, 0.42, 0.5, 0.55)

var _hammocks: Array[Vector3] = []
var _windlass := AABB()
var _stores: Array[Vector3] = []
var _bananas := Vector3.INF
var _puddles: Array[Vector3] = []
var _scuffs: Array[Vector3] = []

func _init(view: View3D) -> void:
	var st := MeshKit.begin()
	_stow_hammocks(st, view)
	_fit_out_the_bow(st, view)
	_stow_the_quarterdeck(st, view)
	_hang_bananas(st, view)
	_scuff_the_guns(st, view)
	mesh = MeshKit.commit(st)
	_splash_the_pump_room(view)

# The middle of every rolled hammock.
func hammocks() -> Array[Vector3]:
	return _hammocks

# The windlass's bounds, barrel and bitts.
func windlass() -> AABB:
	return _windlass

# Where each thing stowed on the quarterdeck stands.
func stores() -> Array[Vector3]:
	return _stores

# The middle of the bunch hung under the mainmast top.
func bananas() -> Vector3:
	return _bananas

# The middle of each puddle in the pump room.
func puddles() -> Array[Vector3]:
	return _puddles

# The middle of each gun's wheel tracks.
func scuffs() -> Array[Vector3]:
	return _scuffs

# Where the rats run: along the tops of the hammocks.
static func hammock_top() -> float:
	return RAIL_TOP + HAMMOCK_RADIUS * 2.0

# Hammocks rolled and lashed along the rail top, the way a fighting ship stowed them, on every
# straight run of rail between the gun ports.
func _stow_hammocks(st: SurfaceTool, view: View3D) -> void:
	var along_x := Basis(Vector3.BACK, -PI / 2)   # the rolls lie fore and aft
	var pitch := HAMMOCK_LENGTH + HAMMOCK_GAP
	for run in view.rail_runs():
		var count := floori((run.y - run.x + HAMMOCK_GAP) / pitch)
		var from := (run.x + run.y - count * pitch + HAMMOCK_GAP) / 2.0
		for k in count:
			var centre := Vector3(from + k * pitch + HAMMOCK_LENGTH / 2.0, RAIL_TOP + HAMMOCK_RADIUS, run.z)
			var shade := DeckDresser.CANVAS.darkened(0.15 + 0.07 * ((k * 7 + int(run.x)) % 3))
			MeshKit.cylinder(st, centre - Vector3(HAMMOCK_LENGTH / 2.0, 0, 0), HAMMOCK_RADIUS, HAMMOCK_LENGTH, 8, shade, along_x)
			for u in [-0.3, 0.3]:
				MeshKit.torus(st, centre + Vector3(u * HAMMOCK_LENGTH, 0, 0), HAMMOCK_RADIUS + 0.005, 0.015, DeckDresser.ROPE, along_x, 8)
			_hammocks.append(centre)

# A windlass across the bow on the first column of tiles, which nobody walks on, with its cable
# running forward to the hawse holes; and in each forward corner, spare coils and a lashed spar.
func _fit_out_the_bow(st: SurfaceTool, view: View3D) -> void:
	var r := view.deck_rect()
	var mid := r.get_center().y
	var x := r.position.x + 0.5
	var half := 2.1
	MeshKit.cylinder(st, Vector3(x, 0.42, mid - half), 0.22, half * 2.0, 10, DeckDresser.MID, Basis(Vector3.RIGHT, PI / 2))
	for z in [-half - 0.15, 0.0, half + 0.15]:
		MeshKit.box(st, Vector3(x, 0.42, mid + z), Vector3(0.4, 0.84, 0.3), DeckDresser.DARK)
	_windlass = AABB(Vector3(x - 0.24, 0, mid - half - 0.3), Vector3(0.48, 0.84, half * 2.0 + 0.6))
	var z := -half + 0.3
	while z < half - 0.2:
		if absf(z) > 0.25:
			MeshKit.torus(st, Vector3(x, 0.42, mid + z), 0.23, 0.02, DeckDresser.IRON, Basis(Vector3.RIGHT, PI / 2), 10)
		z += 0.38
	for k in 4:   # handspikes left in their sockets
		var a := 0.6 + k * 1.5
		var at := Vector3(x, 0.42, mid + (-1.2 if k % 2 else 1.2))
		MeshKit.strut(st, at, at + Vector3(cos(a), sin(a), 0) * 0.55, 0.05, DeckDresser.LIGHT)
	for side in [-1.0, 1.0]:   # the cable, out under the bow to the hawse holes
		for k in 9:
			var link := Vector3(x - 0.3 - k * 0.22, 0.04, mid + side * (1.0 + k * 0.08))
			MeshKit.torus(st, link, 0.07, 0.022, DeckDresser.IRON, Basis(Vector3.FORWARD, PI / 2) if k % 2 else Basis(Vector3.RIGHT, PI / 2), 6)
	for edge in [r.position.y, r.end.y]:
		var inboard := signf(mid - edge)
		_coil(st, Vector3(r.position.x + 0.6, 0, edge + inboard * 0.9), 0.3)
		_coil(st, Vector3(r.position.x + 0.6, 0, edge + inboard * 2.1), 0.26)
		var spar := Vector3(r.position.x + 0.15, 0.09, edge + inboard * 0.6)
		MeshKit.cylinder(st, spar, 0.09, 2.6, 8, DeckDresser.LIGHT, Basis(Vector3.RIGHT, inboard * PI / 2))

# Along the quarterdeck's sides, clear of the helm: the captain's sea chest, a crate of bananas
# and two coils of rope.
func _stow_the_quarterdeck(st: SurfaceTool, view: View3D) -> void:
	var r := view.deck_rect()
	var x := view.quarterdeck_start()
	if not is_finite(x):
		return
	var y := View3D.QUARTERDECK_HEIGHT
	var chest := Vector3(x + 1.4, y, r.position.y + 0.7)
	MeshKit.box(st, chest + Vector3(0, 0.21, 0), Vector3(0.8, 0.42, 0.5), DeckDresser.RED)
	MeshKit.lathe(st, chest + Vector3(-0.4, 0.42, 0), PackedVector2Array([Vector2(0.25, 0), Vector2(0.25, 0.8)]), 8, DeckDresser.RED,
		Basis(Vector3.BACK, -PI / 2) * Basis.from_scale(Vector3(1, 1, 0.5)))   # a rounded lid, fore and aft
	for dx in [-0.3, 0.3]:
		MeshKit.box(st, chest + Vector3(dx, 0.21, 0), Vector3(0.06, 0.44, 0.52), DeckDresser.IRON)
	MeshKit.box(st, chest + Vector3(0, 0.36, 0.26), Vector3(0.1, 0.12, 0.04), DeckDresser.BRASS)
	var crate := Vector3(x + 1.4, y, r.end.y - 0.7)
	_crate(st, crate, 0.6)
	_bunch(st, crate + Vector3(-0.08, 0.66, 0))
	_bunch(st, crate + Vector3(0.14, 0.64, 0.12), 0.9)
	var coils := [Vector3(r.end.x - 0.8, y, r.position.y + 0.7), Vector3(r.end.x - 0.8, y, r.end.y - 0.7)]
	for at in coils:
		_coil(st, at, 0.28)
	_stores.append_array([chest, crate] + coils)

# A bunch of bananas on a line from the forward edge of the mainmast's fighting top: forward, out of the
# way of the mast's lantern aft and the shrouds either side, and just past the top, so the game camera
# can see it.
func _hang_bananas(st: SurfaceTool, view: View3D) -> void:
	var masts := view.dresser().masts()
	if masts.is_empty():
		return
	masts.sort()
	var top := view.cell_centre(masts[masts.size() / 2]) + Vector3(-0.62, DeckDresser.TOP_HEIGHT - 0.05, 0)
	_bananas = top + Vector3(-0.15, -0.45, 0)
	MeshKit.strut(st, top, _bananas + Vector3(0, 0.16, 0), 0.015, DeckDresser.ROPE)
	_bunch(st, _bananas, 1.3)

# A crate of light boards, with dark battens down the corners and across the lid.
static func _crate(st: SurfaceTool, at: Vector3, size: float) -> void:
	MeshKit.box(st, at + Vector3(0, size / 2.0, 0), Vector3.ONE * size, DeckDresser.LIGHT)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		MeshKit.box(st, at + Vector3(c.x * (size / 2.0 - 0.02), size / 2.0, c.y * (size / 2.0 - 0.02)), Vector3(0.06, size + 0.01, 0.06), DeckDresser.MID)
	MeshKit.box(st, at + Vector3(0, size, 0), Vector3(size + 0.02, 0.05, 0.06), DeckDresser.MID)
	MeshKit.box(st, at + Vector3(0, size, 0), Vector3(0.06, 0.05, size + 0.02), DeckDresser.MID)

# A hand of bananas round a stalk, each one bent in two.
static func _bunch(st: SurfaceTool, at: Vector3, size := 1.0) -> void:
	MeshKit.strut(st, at, at + Vector3(0, 0.16, 0) * size, 0.03 * size, DeckDresser.DARK)
	for k in 6:
		var out := Vector3(cos(k * 1.05), 0, sin(k * 1.05))
		var base := at + out * 0.04 * size
		var knee := base + (out * 0.1 + Vector3(0, 0.02, 0)) * size
		var tip := knee + (out * 0.05 + Vector3(0, 0.1, 0)) * size
		MeshKit.strut(st, base, knee, 0.05 * size, BANANA)
		MeshKit.strut(st, knee, tip, 0.045 * size, BANANA)
		MeshKit.strut(st, tip, tip + Vector3(0, 0.02, 0) * size, 0.025 * size, DeckDresser.DARK)

# A coil of rope flaked down on the deck: rings stacked smaller towards the top.
static func _coil(st: SurfaceTool, at: Vector3, radius: float) -> void:
	for k in 3:
		MeshKit.torus(st, at + Vector3(0, 0.035 + k * 0.045, 0), radius * (1.0 - k * 0.25), 0.035, DeckDresser.ROPE, Basis.IDENTITY, 12)

# Pale tracks worn into the deck by each gun's trucks as it recoils inboard: flat, so the walkway
# still reads as open.
func _scuff_the_guns(st: SurfaceTool, view: View3D) -> void:
	var mid := view.deck_rect().get_center().y
	var worn := View3D.FLOOR_COLOR.lightened(0.3)
	for s in view.get_tree().get_nodes_in_group("stations"):
		if not "phase" in s:
			continue
		var gun := view.to_3d(s.global_position)
		var inboard := signf(mid - gun.z)
		var centre := gun + Vector3(0, 0.006, inboard * 0.85)
		for x in [-0.3, 0.3]:
			MeshKit.box(st, centre + Vector3(x, 0, 0), Vector3(0.08, 0.004, 1.0), worn)
		_scuffs.append(centre)

# Puddles slopped from the pump: a few glossy slicks on the pump room floor, clear of the pump.
# They're a surface of their own, so they can shine.
func _splash_the_pump_room(view: View3D) -> void:
	var pump: Node2D = null
	for s in view.get_tree().get_nodes_in_group("stations"):
		if s is Pump:
			pump = s
	if pump == null:
		return
	var hull := view.hull
	var at := view.to_3d(pump.global_position)
	var room: String = hull.get_cell_tile_data(hull.local_to_map(hull.to_local(pump.global_position))).get_custom_data("room")
	var cells: Array[Vector2i] = []
	for cell in hull.get_used_cells():
		var data := hull.get_cell_tile_data(cell)
		if data.get_collision_polygons_count(0) == 0 and data.get_custom_data("room") == room \
				and view.cell_centre(cell).distance_to(at) > 1.2:
			cells.append(cell)
	cells.sort()
	var st := MeshKit.begin()
	for k in mini(3, cells.size()):
		var cell := cells[(k * 7 + 2) % cells.size()]
		var centre := view.cell_centre(cell) + Vector3(0.15 * (k - 1), 0.008, 0.1 * (1 - k))
		MeshKit.cylinder(st, centre, 0.32 + 0.08 * k, 0.004, 14, PUDDLE, Basis.from_scale(Vector3(1, 1, 0.6)))
		_puddles.append(centre)
	var slick := StandardMaterial3D.new()
	slick.vertex_color_use_as_albedo = true
	slick.vertex_color_is_srgb = true
	slick.roughness = 0.08
	slick.metallic_specular = 0.9
	slick.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, slick)
