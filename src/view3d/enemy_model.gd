class_name EnemyModel
extends Node3D
# The enemy ship in 3D, built like ours but smaller and plainer: a brown hull with rounded bow and
# stern, a planked deck, a bulwark with gun ports, and tapered masts with fighting tops. Bow along -x
# like ours, guns along +z to face us. Its bulwark is painted navy inboard and it flies a navy
# pennant, where ours is red with a black flag, so the two never get mixed up.
# It rolls on its own swell (View3D calls sway), flashes a ripple broadside when it fires, and wears
# scorch marks, shot holes and a broken foremast as its hull drops (show_hull).

const LENGTH := 12.0
const BEAM := 3.6
const KEEL := -1.0         # below the sea, which sits at -0.8
const DECK := 0.3
const BULWARK := 0.75
const PAINT := Color(0.16, 0.26, 0.42)   # inboard, and the pennant: navy where ours is red
const SCORCH := Color("1a120c")
const PORTS := 5
const MASTS := [Vector2(-3.0, 2.4), Vector2(0.4, 2.8), Vector2(3.6, 2.1)]   # x, height of the fighting top
const BREAK := 1.2          # where the foremast snaps
const ROLL := 0.02          # radians: smaller than us, so it rolls a little more
const HEAVE := 0.1
const SINK := 0.35          # how much lower it sits with no hull left
const LIST := 0.04          # and how far it heels towards us
const FLASH_TIME := 0.25
const SMOKE_TIME := 1.2
const RIPPLE := 0.07        # seconds between one gun and the next

var _rig := Node3D.new()    # everything that rolls
var _outline := PackedVector2Array()   # the hull's edge at deck level, (x, z)
var _ports := PackedVector3Array()   # muzzles, model space
var _flashes: Array[MeshInstance3D] = []
var _smoke: Array[MeshInstance3D] = []
var _flash_light := OmniLight3D.new()
var _marks: Array[MeshInstance3D] = []
var _thresholds: Array[float] = []   # mark i shows once the hull's share drops below this
var _foretop := MeshInstance3D.new()
var _fired_at := -INF
var _share := 1.0

# `deck` is our own plank material, so both decks are cut from the same timber.
func _init(deck: Material) -> void:
	add_child(_rig)
	_build_outline()
	var st := MeshKit.begin()
	_hull(st)
	_bulwark(st)
	_masts(st)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = MeshKit.commit(st)
	_rig.add_child(body)
	_rig.add_child(_deck(deck))
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

# Straight sides, rounded stern corners at +x and a round bow at -x, the same shape as our hull.
func _build_outline() -> void:
	var h := BEAM / 2.0
	var aft := LENGTH / 2.0
	var waist := -LENGTH / 2.0 + 2.0
	_outline = PackedVector2Array([Vector2(waist, -h), Vector2(aft - 0.5, -h)])
	_outline += _curve(Vector2(aft - 0.5, -h), Vector2(aft, -h), Vector2(aft, -h + 0.5))
	_outline.append(Vector2(aft, h - 0.5))
	_outline += _curve(Vector2(aft, h - 0.5), Vector2(aft, h), Vector2(aft - 0.5, h))
	_outline.append(Vector2(waist, h))
	_outline += _curve(Vector2(waist, h), Vector2(waist - 1.6, h), Vector2(waist - 2.6, 0))
	_outline += _curve(Vector2(waist - 2.6, 0), Vector2(waist - 1.6, -h), Vector2(waist, -h))
	_outline.remove_at(_outline.size() - 1)

func _curve(a: Vector2, control: Vector2, b: Vector2, steps := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, steps + 1):
		var t := float(i) / steps
		out.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return out

# A quad wound to face `out`, whichever order the corners came in.
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) < 0.0:
		MeshKit.quad(st, a, d, c, b, color)
	else:
		MeshKit.quad(st, a, b, c, d, color)

func _hull(st: SurfaceTool) -> void:
	for i in _outline.size():
		var a := _outline[i]
		var b := _outline[(i + 1) % _outline.size()]
		var out := (a + b) / 2.0
		_face(st, Vector3(a.x, KEEL, a.y), Vector3(b.x, KEEL, b.y), Vector3(b.x, DECK, b.y), Vector3(a.x, DECK, a.y),
			View3D.HULL_COLOR, Vector3(out.x, 0, out.y))
	MeshKit.box(st, Vector3(-1.4, DECK + 0.06, 0), Vector3(1.1, 0.12, 0.8), DeckDresser.CAP)   # hatch
	MeshKit.strut(st, Vector3(-LENGTH / 2.0 - 0.4, DECK + 0.6, 0), Vector3(-LENGTH / 2.0 - 2.0, DECK + 1.2, 0), 0.12, DeckDresser.CAP)   # bowsprit

func _deck(material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in Geometry2D.triangulate_polygon(_outline):
		st.add_vertex(Vector3(_outline[i].x, DECK, _outline[i].y))
	var node := MeshInstance3D.new()
	node.name = "Deck"
	node.mesh = st.commit()
	node.material_override = material
	return node

# Our bulwark, smaller: short pieces round the edge, painted inboard and capped with a rail. On the
# side facing us a gun runs out through each gap, on a red carriage like ours.
func _bulwark(st: SurfaceTool) -> void:
	var h := BEAM / 2.0
	var guns: Array[float] = []
	for i in PORTS:
		guns.append(lerpf(-3.4, 4.4, float(i) / (PORTS - 1)))
	for i in _outline.size():
		var a := _outline[i]
		var b := _outline[(i + 1) % _outline.size()]
		var pieces := ceili(a.distance_to(b) / 0.5)
		for k in pieces:
			var p := a.lerp(b, float(k) / pieces)
			var q := a.lerp(b, float(k + 1) / pieces)
			var m := (p + q) / 2.0
			var inboard := Vector2(q.y - p.y, p.x - q.x).normalized()
			if inboard.dot(-m) < 0.0:
				inboard = -inboard
			var along := Basis(Vector3.UP, atan2(p.y - q.y, q.x - p.x))
			var length := p.distance_to(q) + 0.02
			var at := func(offset: float, y: float) -> Vector3:
				var c := m + inboard * offset
				return Vector3(c.x, DECK + y, c.y)
			if absf(m.y - h) < 0.01 and guns.any(func(g): return absf(g - m.x) < 0.3):
				MeshKit.box(st, at.call(0.1, 0.1), Vector3(length, 0.2, 0.24), View3D.RAIL_COLOR, along)
				continue
			MeshKit.box(st, at.call(0.1, BULWARK / 2.0), Vector3(length, BULWARK, 0.2), View3D.BULWARK_COLOR, along)
			MeshKit.box(st, at.call(0.21, BULWARK / 2.0 - 0.02), Vector3(length, BULWARK - 0.12, 0.02), PAINT, along)
			MeshKit.box(st, at.call(0.1, BULWARK + 0.035), Vector3(length + 0.02, 0.07, 0.3), View3D.RAIL_COLOR, along)
	var out := Basis(Vector3.RIGHT, PI / 2)   # a cylinder's axis along +z
	for x in guns:
		var y := DECK + 0.38
		MeshKit.box(st, Vector3(x, DECK + 0.15, h - 0.55), Vector3(0.4, 0.3, 0.6), DeckDresser.RED)
		MeshKit.cylinder(st, Vector3(x, y, h - 0.8), 0.09, 1.1, 8, DeckDresser.IRON, out)
		_ports.append(Vector3(x, y, h + 0.5))

# Our masts, plainer: a tapered lower mast with iron bands, a fighting top, and a short topmast with a
# brass truck. The foremast's top half is its own mesh, so it can come down.
func _masts(st: SurfaceTool) -> void:
	var top := MeshKit.begin()
	for i in MASTS.size():
		var at := Vector3(MASTS[i].x, DECK, 0)
		var height: float = MASTS[i].y
		var radius := func(y: float) -> float: return lerpf(0.2, 0.13, y / height)
		var split: float = BREAK if i == 0 else height
		MeshKit.lathe(st, at, PackedVector2Array([Vector2(0.2, 0), Vector2(radius.call(split), split)]), 10, DeckDresser.CAP)
		var upper := top if i == 0 else st
		if split < height:
			MeshKit.lathe(upper, at + Vector3(0, split, 0), PackedVector2Array([Vector2(radius.call(split), 0), Vector2(0.13, height - split)]), 10, DeckDresser.CAP)
		MeshKit.torus(st, at + Vector3(0, 0.6, 0), radius.call(0.6), 0.02, DeckDresser.IRON)
		MeshKit.box(upper, at + Vector3(0, height, 0), Vector3(1.0, 0.08, 0.85), DeckDresser.DARK)
		MeshKit.lathe(upper, at + Vector3(0, height, 0), PackedVector2Array([Vector2(0.08, 0), Vector2(0.05, 1.1)]), 8, DeckDresser.LIGHT)
		MeshKit.ball(upper, at + Vector3(0, height + 1.12, 0), 0.07, DeckDresser.BRASS)
		if i == 1:   # the pennant, streaming aft from the main topmast
			MeshKit.box(st, at + Vector3(0.5, height + 0.9, 0), Vector3(0.9, 0.22, 0.02), PAINT)
	_foretop.mesh = MeshKit.commit(top)

func _mark(build: Callable, threshold: float) -> void:
	var st := MeshKit.begin()
	build.call(st)
	var m := MeshInstance3D.new()
	m.mesh = MeshKit.commit(st)
	m.visible = false
	_rig.add_child(m)
	_marks.append(m)
	_thresholds.append(threshold)

# Scorched planks and shot holes through the near bulwark, in the order they appear, then the
# foremast snaps and its top lies across the deck.
func _build_wear() -> void:
	var h := BEAM / 2.0
	var hits := [[-2.4, 0.85], [2.6, 0.7], [-0.6, 0.55], [4.6, 0.4], [-4.0, 0.25]]
	for hit in hits:
		var x: float = hit[0]
		_mark(func(st):
			MeshKit.blob(st, Vector3(x, DECK + 0.01, h * 0.2), Vector3(0.4, 0.02, 0.28), SCORCH)
			MeshKit.box(st, Vector3(x + 0.45, DECK + BULWARK * 0.6, h - 0.1), Vector3(0.4, 0.35, 0.24), SCORCH)
			MeshKit.box(st, Vector3(x + 0.45, DECK + BULWARK + 0.04, h - 0.1), Vector3(0.45, 0.03, 0.32), SCORCH), hit[1])
	var fore := Vector3(MASTS[0].x, DECK, 0)
	_mark(func(st):
		MeshKit.strut(st, fore + Vector3(0, BREAK, 0), fore + Vector3(1.4, 0.15, 1.2), 0.13, DeckDresser.CAP)
		MeshKit.box(st, fore + Vector3(1.4, 0.12, 1.2), Vector3(1.0, 0.08, 0.85), DeckDresser.DARK, Basis(Vector3.UP, 0.6)), 0.5)

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
