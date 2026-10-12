class_name StationModel
extends Node3D
# A station in 3D (look book Volume V), built from MeshKit primitives on its one tile. Local +z points
# outboard, so a cannon's barrel runs out through its gun port once the view turns it to face its side.
# Cannons carry the phase lamp, and the pump's handle rocks while someone works it.

const COPPER := Color("b0643a")
const WATER := Color("2f6f8f")
const LAMP_SIZE := Vector3(0.26, 0.1, 0.26)
const PUMP_STROKE := 0.35     # how far the handle tips each way, radians
const PUMP_RATE := 4.0        # strokes per second, near enough
const PUMP_SETTLE := 1.5      # radians per second as the handle comes to rest

var kind: String
var lamp: MeshInstance3D      # cannons only
var handle: Node3D            # the pump only
var _body := MeshInstance3D.new()
var _stroke := 0.0

func _init(kind_: String) -> void:
	kind = kind_
	var st := MeshKit.begin()
	match kind:
		"cannon": _cannon(st)
		"magazine": _magazine(st)
		"shot_locker": _shot_locker(st)
		"water_butt": _water_butt(st)
		"pump": _pump(st)
		"lumber_crate": _lumber_crate(st)
		_: MeshKit.box(st, Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.8), Color.GRAY)
	_body.name = "Body"
	_body.mesh = MeshKit.commit(st)
	add_child(_body)

# The body's bounds in the parent's space: what a crew member would bump into.
func body_aabb() -> AABB:
	return transform * _body.get_aabb()

func vertex_count() -> int:
	return _body.mesh.surface_get_array_len(0)

# Rock the handle while someone works the pump; let it come to rest when they stop.
func work_pump(manned: bool, delta: float) -> void:
	if manned:
		_stroke += delta * PUMP_RATE
		handle.rotation.z = sin(_stroke) * PUMP_STROKE
	else:
		handle.rotation.z = move_toward(handle.rotation.z, 0.0, PUMP_SETTLE * delta)
		_stroke = asin(handle.rotation.z / PUMP_STROKE)

# A gun on a red truck carriage, barrel out along +z, with the phase lamp on the back of the carriage.
func _cannon(st: SurfaceTool) -> void:
	var across := Basis(Vector3.BACK, -PI / 2)   # a cylinder's axis along x
	for side in [-1, 1]:
		MeshKit.box(st, Vector3(side * 0.25, 0.27, 0), Vector3(0.09, 0.3, 0.95), DeckDresser.RED)
		MeshKit.box(st, Vector3(side * 0.25, 0.49, -0.22), Vector3(0.09, 0.16, 0.45), DeckDresser.RED)
		MeshKit.cylinder(st, Vector3(side * 0.25 - 0.06, 0.48, 0.12), 0.04, 0.12, 8, DeckDresser.IRON, across)
	for z in [-0.33, 0.33]:
		MeshKit.box(st, Vector3(0, 0.13, z), Vector3(0.66, 0.08, 0.1), DeckDresser.DARK)
		for side in [-1, 1]:
			MeshKit.cylinder(st, Vector3(side * 0.36 - 0.04, 0.13, z), 0.13, 0.08, 12, DeckDresser.DARK, across)
	MeshKit.box(st, Vector3(0, 0.42, -0.2), Vector3(0.32, 0.08, 0.5), DeckDresser.MID)   # the quoin
	var barrel := PackedVector2Array([Vector2(0, -0.64), Vector2(0.05, -0.64), Vector2(0.05, -0.58), Vector2(0.03, -0.54),
		Vector2(0.16, -0.52), Vector2(0.17, -0.38), Vector2(0.15, -0.33), Vector2(0.155, 0.12), Vector2(0.13, 0.17),
		Vector2(0.125, 0.6), Vector2(0.15, 0.64), Vector2(0.15, 0.72), Vector2(0.075, 0.72), Vector2(0.075, 0.5), Vector2(0, 0.5)])
	MeshKit.lathe(st, Vector3(0, 0.48, 0.12), barrel, 16, DeckDresser.IRON, Basis(Vector3.RIGHT, PI / 2))
	MeshKit.box(st, Vector3(0.36, 0.36, -0.42), Vector3(0.05, 0.72, 0.05), DeckDresser.IRON)   # the lamp's stand
	var cube := BoxMesh.new()
	cube.size = LAMP_SIZE
	lamp = MeshInstance3D.new()
	lamp.name = "Lamp"
	lamp.mesh = cube
	lamp.position = Vector3(0.36, 0.72 + LAMP_SIZE.y / 2.0, -0.42)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color.GRAY
	glow.emission_enabled = true
	glow.emission_energy_multiplier = 1.5
	lamp.material_override = glow
	add_child(lamp)

# Powder kegs: three on the deck and one on top.
func _magazine(st: SurfaceTool) -> void:
	for at in [Vector2(-0.22, -0.15), Vector2(0.22, -0.15), Vector2(0, 0.22)]:
		MeshKit.barrel(st, Vector3(at.x, 0, at.y), 0.24, 0.5, DeckDresser.KEG, DeckDresser.IRON)
	MeshKit.barrel(st, Vector3(0, 0.5, 0), 0.24, 0.5, DeckDresser.KEG, DeckDresser.IRON)

# A crate with a pyramid of shot on a tray on top.
func _shot_locker(st: SurfaceTool) -> void:
	_crate(st, Vector3.ZERO, 0.8)
	MeshKit.box(st, Vector3(0, 0.84, 0), Vector3(0.64, 0.08, 0.64), DeckDresser.MID)
	for layer in 3:
		var n := 3 - layer
		for a in n:
			for b in n:
				MeshKit.ball(st, Vector3((a - (n - 1) / 2.0) * 0.18, 0.97 + layer * 0.14, (b - (n - 1) / 2.0) * 0.18), 0.09, DeckDresser.IRON)

# A tall cask standing open, full to the brim.
func _water_butt(st: SurfaceTool) -> void:
	MeshKit.barrel(st, Vector3.ZERO, 0.42, 0.95, DeckDresser.MID, DeckDresser.IRON, 12)
	MeshKit.cylinder(st, Vector3(0, 0.9, 0), 0.35, 0.04, 12, WATER)

# A dark pump barrel with a copper spout; the handle is its own node so it can rock.
func _pump(st: SurfaceTool) -> void:
	MeshKit.lathe(st, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0), Vector2(0.3, 0.12), Vector2(0.18, 0.18),
		Vector2(0.16, 0.95), Vector2(0.2, 1.0), Vector2(0, 1.02)]), 12, DeckDresser.DARK)
	MeshKit.box(st, Vector3(0, 1.15, 0), Vector3(0.08, 0.5, 0.08), DeckDresser.DARK)
	MeshKit.lathe(st, Vector3(0.04, 0.8, 0), PackedVector2Array([Vector2(0.06, 0), Vector2(0.05, 0.4)]), 8, COPPER, Basis(Vector3.BACK, -PI / 2))
	handle = Node3D.new()
	handle.name = "Handle"
	handle.position = Vector3(0, 1.38, 0)
	var bar := MeshKit.begin()
	MeshKit.box(bar, Vector3.ZERO, Vector3(1.2, 0.06, 0.08), DeckDresser.LIGHT)
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshKit.commit(bar)
	handle.add_child(mesh)
	add_child(handle)

# A crate with planks stacked across it.
func _lumber_crate(st: SurfaceTool) -> void:
	_crate(st, Vector3(0, 0, 0.12), 0.7)
	for k in 3:
		MeshKit.box(st, Vector3((k % 2) * 0.05, 0.735 + k * 0.075, ((k * 5) % 3 - 1) * 0.03), Vector3(0.88, 0.07, 0.24),
			DeckDresser.LIGHT if k % 2 else DeckDresser.CAP, Basis(Vector3.UP, (k - 1) * 0.03))

# A plank crate `s` metres on a side, standing on `base`, with darker corner posts and top battens.
func _crate(st: SurfaceTool, base: Vector3, s: float) -> void:
	var t := 0.06
	MeshKit.box(st, base + Vector3(0, s / 2.0, 0), Vector3(s, s, s), DeckDresser.LIGHT)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c: Vector2 = corner * (s / 2.0 - t / 2.0 + 0.01)
		MeshKit.box(st, base + Vector3(c.x, s / 2.0, c.y), Vector3(t, s + 0.01, t), DeckDresser.MID)
	MeshKit.box(st, base + Vector3(0, s, 0), Vector3(s + 0.02, t, t), DeckDresser.MID)
	MeshKit.box(st, base + Vector3(0, s, 0), Vector3(t, t, s + 0.02), DeckDresser.MID)
