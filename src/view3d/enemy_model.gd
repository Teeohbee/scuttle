class_name EnemyModel
extends Node3D
# The enemy ship in 3D, built from MeshKit primitives. Bow along -x like ours, guns along +z to face
# us. It's tarred black with a bone stripe and black masts, so it never reads as our own brown ship.
# It rolls on its own swell (View3D calls sway), flashes a ripple broadside when it fires, and wears
# scorch marks, shot holes and a broken foremast as its hull drops (show_hull).

const LENGTH := 12.0
const BEAM := 3.6
const KEEL := -1.0         # below the sea, which sits at -0.8
const DECK := 0.35
const BULWARK := 0.5
const TAR := Color("17161a")
const STRAKE := Color("26303a")
const BONE := Color("c9bf9f")
const PLANKS := Color("4a4038")
const PORT := Color("0a0808")
const SCORCH := Color("0d0b0a")
const PORTS := 5
const MASTS := [Vector3(-3.6, 0, 3.4), Vector3(0.2, 0, 3.9), Vector3(3.8, 0, 3.0)]   # x, -, height
const ROLL := 0.02          # radians: smaller than us, so it rolls a little more
const HEAVE := 0.1
const SINK := 0.35          # how much lower it sits with no hull left
const LIST := 0.04          # and how far it heels towards us
const FLASH_TIME := 0.25
const SMOKE_TIME := 1.2
const RIPPLE := 0.07        # seconds between one gun and the next

var _rig := Node3D.new()    # everything that rolls
var _ports := PackedVector3Array()   # muzzles, model space
var _flashes: Array[MeshInstance3D] = []
var _smoke: Array[MeshInstance3D] = []
var _flash_light := OmniLight3D.new()
var _marks: Array[MeshInstance3D] = []
var _thresholds: Array[float] = []   # mark i shows once the hull's share drops below this
var _foretop := MeshInstance3D.new()
var _fired_at := -INF
var _share := 1.0

func _init() -> void:
	add_child(_rig)
	var st := MeshKit.begin()
	_hull(st)
	_guns(st)
	_masts(st)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = MeshKit.commit(st)
	_rig.add_child(body)
	_rig.add_child(_foretop)
	_build_wear()
	_build_broadside()

func _process(_delta: float) -> void:
	var since := Time.get_ticks_msec() / 1000.0 - _fired_at
	var brightest := 0.0
	for i in _flashes.size():
		var t := since - i * RIPPLE
		var flash := clampf(1.0 - t / FLASH_TIME, 0.0, 1.0) if t >= 0.0 else 0.0
		_flashes[i].visible = flash > 0.0
		_flashes[i].scale = Vector3.ONE * (0.4 + 0.6 * flash)
		brightest = maxf(brightest, flash)
		var puff := t / SMOKE_TIME
		_smoke[i].visible = puff >= 0.0 and puff < 1.0
		if _smoke[i].visible:
			_smoke[i].scale = Vector3.ONE * (0.5 + puff * 1.2)
			_smoke[i].position = _ports[i] + Vector3(0, puff * 0.8, 0.3 + puff * 0.6)
			(_smoke[i].material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - puff)
	_flash_light.light_energy = brightest * 4.0

# Roll, pitch and heave on a swell of its own, by `amount` (0 while the view lines up with the 2D).
func sway(amount: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var hurt := 1.0 - _share
	_rig.rotation = Vector3(sin(t * 0.53 + 1.3) * ROLL + hurt * LIST, 0, sin(t * 0.37 + 0.4) * ROLL * 0.6) * amount
	_rig.position.y = (sin(t * 0.71 + 2.0) * HEAVE - hurt * SINK) * amount

func roll() -> Vector3:
	return _rig.rotation

func fire() -> void:
	_fired_at = Time.get_ticks_msec() / 1000.0

func lit_flashes() -> int:
	return _flashes.filter(func(f): return f.visible).size()

# How much hull it has left, 0 to 1. Marks appear one by one as it drops.
func show_hull(share: float) -> void:
	_share = clampf(share, 0.0, 1.0)
	for i in _marks.size():
		_marks[i].visible = _share < _thresholds[i]
	_foretop.visible = _share >= 0.5

func wear_marks() -> int:
	return _marks.filter(func(m): return m.visible).size()

func masts() -> int:
	return MASTS.size()

# Each gun's muzzle, in world space.
func gun_ports() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in _ports:
		out.append(_rig.global_transform * p)
	return out

# Half the beam at x: a square stern at +x, full amidships, a fine bow at -x.
func _half_beam(x: float) -> float:
	var t := 0.5 - x / LENGTH   # 0 at the stern, 1 at the bow
	var w := 1.0
	if t < 0.2:
		w = lerpf(0.82, 1.0, t / 0.2)
	elif t > 0.55:
		w = pow(cos((t - 0.55) / 0.45 * PI / 2.0), 0.6)
	return maxf(w, 0.03) * BEAM / 2.0

# A quad wound to face `out`, whichever order the corners came in.
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) < 0.0:
		MeshKit.quad(st, a, d, c, b, color)
	else:
		MeshKit.quad(st, a, b, c, d, color)

func _hull(st: SurfaceTool) -> void:
	var top := DECK + BULWARK
	var steps := 14
	for i in steps:
		var x0 := LENGTH * (0.5 - float(i) / steps)
		var x1 := LENGTH * (0.5 - float(i + 1) / steps)
		var w0 := _half_beam(x0)
		var w1 := _half_beam(x1)
		for side: float in [-1.0, 1.0]:
			var out := Vector3(0, 0, side)
			var bands := [[KEEL, -0.2, TAR], [-0.2, 0.0, BONE], [0.0, top, TAR]]
			for band in bands:
				_face(st, Vector3(x0, band[0], w0 * side), Vector3(x1, band[0], w1 * side),
					Vector3(x1, band[1], w1 * side), Vector3(x0, band[1], w0 * side), band[2], out)
			# inboard face of the bulwark and its rail
			var i0 := (w0 - 0.1) * side
			var i1 := maxf(w1 - 0.1, 0.0) * side
			_face(st, Vector3(x0, DECK, i0), Vector3(x1, DECK, i1), Vector3(x1, top, i1), Vector3(x0, top, i0), STRAKE, -out)
			_face(st, Vector3(x0, top, i0), Vector3(x1, top, i1), Vector3(x1, top, w1 * side), Vector3(x0, top, w0 * side), BONE, Vector3.UP)
		_face(st, Vector3(x0, DECK, -w0 + 0.1), Vector3(x1, DECK, -maxf(w1 - 0.1, 0.0)),
			Vector3(x1, DECK, maxf(w1 - 0.1, 0.0)), Vector3(x0, DECK, w0 - 0.1), PLANKS, Vector3.UP)
	var stern := LENGTH / 2.0
	var ws := _half_beam(stern)
	_face(st, Vector3(stern, KEEL, -ws), Vector3(stern, KEEL, ws), Vector3(stern, top + 0.3, ws), Vector3(stern, top + 0.3, -ws), TAR, Vector3.RIGHT)
	MeshKit.box(st, Vector3(stern - 0.9, DECK + 0.2, 0), Vector3(1.6, 0.4, BEAM - 0.4), STRAKE)   # a low poop
	MeshKit.box(st, Vector3(-0.6, DECK + 0.08, 0), Vector3(1.2, 0.16, 0.9), STRAKE)                # hatch
	MeshKit.strut(st, Vector3(-LENGTH / 2.0, top, 0), Vector3(-LENGTH / 2.0 - 2.2, top + 0.9, 0), 0.12, TAR)   # bowsprit

# Gun ports along the side facing us, each with a lid propped up and a barrel run out.
func _guns(st: SurfaceTool) -> void:
	var out := Basis(Vector3.RIGHT, PI / 2)   # a cylinder's axis along +z
	for i in PORTS:
		var x := lerpf(-3.8, 4.0, float(i) / (PORTS - 1))
		var z := _half_beam(x)
		var y := DECK + 0.24
		MeshKit.box(st, Vector3(x, y, z + 0.01), Vector3(0.42, 0.3, 0.02), PORT)
		MeshKit.box(st, Vector3(x, y + 0.27, z + 0.12), Vector3(0.44, 0.04, 0.3), BONE, Basis(Vector3.RIGHT, -0.5))
		MeshKit.cylinder(st, Vector3(x, y, z - 0.1), 0.08, 0.45, 8, PORT, out)
		_ports.append(Vector3(x, y, z + 0.4))

func _masts(st: SurfaceTool) -> void:
	for m in MASTS:
		var foremast: bool = m == MASTS[0]
		var height: float = m.z * (0.55 if foremast else 1.0)
		MeshKit.cylinder(st, Vector3(m.x, DECK, 0), 0.12, height, 6, TAR)
		if not foremast:
			_rigging(st, m.x, m.z)
	MeshKit.box(st, Vector3(MASTS[1].x + 0.45, DECK + MASTS[1].z - 0.2, 0), Vector3(0.8, 0.5, 0.03), TAR)   # black flag
	var top := MeshKit.begin()
	var fore: Vector3 = MASTS[0]
	MeshKit.cylinder(top, Vector3(fore.x, DECK + fore.z * 0.55, 0), 0.1, fore.z * 0.45, 6, TAR)
	_rigging(top, fore.x, fore.z)
	_foretop.mesh = MeshKit.commit(top)

# A yard across the ship with its sail furled on it.
func _rigging(st: SurfaceTool, x: float, height: float) -> void:
	var y := DECK + height * 0.72
	MeshKit.strut(st, Vector3(x, y, -1.4), Vector3(x, y, 1.4), 0.08, TAR)
	MeshKit.blob(st, Vector3(x + 0.08, y - 0.05, 0), Vector3(0.14, 0.12, 1.2), BONE.darkened(0.25))

func _mark(build: Callable, threshold: float) -> void:
	var st := MeshKit.begin()
	build.call(st)
	var m := MeshInstance3D.new()
	m.mesh = MeshKit.commit(st)
	m.visible = false
	_rig.add_child(m)
	_marks.append(m)
	_thresholds.append(threshold)

# Scorched planks and shot holes, in the order they appear, then the foremast snaps and lies on deck.
func _build_wear() -> void:
	var hits := [[-2.4, 0.85], [2.6, 0.7], [-0.4, 0.55], [4.4, 0.4], [-4.6, 0.25]]
	for h in hits:
		var x: float = h[0]
		var z := _half_beam(x)
		_mark(func(st):
			MeshKit.blob(st, Vector3(x, DECK + 0.01, z * 0.35), Vector3(0.7, 0.02, 0.5), SCORCH)
			MeshKit.box(st, Vector3(x + 0.5, DECK + BULWARK * 0.6, z), Vector3(0.45, 0.35, 0.16), SCORCH)
			MeshKit.box(st, Vector3(x + 0.5, DECK + BULWARK + 0.01, z), Vector3(0.5, 0.03, 0.14), SCORCH), h[1])
	var fore: Vector3 = MASTS[0]
	_mark(func(st):
		MeshKit.strut(st, Vector3(fore.x, DECK + fore.z * 0.5, 0), Vector3(fore.x + 1.4, DECK + 0.15, 1.3), 0.1, TAR)
		MeshKit.blob(st, Vector3(fore.x + 0.9, DECK + 0.2, 0.5), Vector3(0.5, 0.1, 0.6), BONE.darkened(0.25)), 0.5)

func _build_broadside() -> void:
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color(1.0, 0.75, 0.35)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.6, 0.2)
	fire.emission_energy_multiplier = 4.0
	var ball := SphereMesh.new()
	ball.radius = 0.32
	ball.height = 0.5
	var puff := SphereMesh.new()
	puff.radius = 0.4
	puff.height = 0.7
	for p in _ports:
		var flash := MeshInstance3D.new()
		flash.mesh = ball
		flash.material_override = fire
		flash.position = p
		flash.visible = false
		_rig.add_child(flash)
		_flashes.append(flash)
		var smoke := MeshInstance3D.new()
		smoke.mesh = puff
		var grey := StandardMaterial3D.new()
		grey.albedo_color = Color(0.82, 0.8, 0.76, 0.0)
		grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke.material_override = grey
		smoke.visible = false
		_rig.add_child(smoke)
		_smoke.append(smoke)
	_flash_light.light_color = Color(1.0, 0.6, 0.25)
	_flash_light.omni_range = 9.0
	_flash_light.light_energy = 0.0
	_flash_light.position = Vector3(0, DECK + 0.5, BEAM)
	_rig.add_child(_flash_light)
