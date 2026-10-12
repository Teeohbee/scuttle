class_name Monkey
extends Node3D
# A pirate monkey (look book Volume V): a big head with a heart-shaped face and ears, long arms, short
# bowed legs, a curled tail, and a waistcoat, tricorn and deck ring in the player's colour so players
# can find themselves from above. `look` varies the fur and adds an eyepatch, a peg leg, a hook or an
# earring. Built from MeshKit on hip, shoulder and tail pivots; animate() drives them from how the
# monkey moved since the last frame, so it only needs its 2D crew member's position.

const HEIGHT := 1.5      # to the top of the hat
const SCALE := 1.2
const WALK_SPEED := 0.3  # m/s: slower than this is standing still
const STRIDE := 11.0     # leg swings, in radians per second of walking
const TURN := 12.0       # how quickly it turns to face where it's going

const FUR := [Color("6a4026"), Color("8a5a32"), Color("4a3022"), Color("a0703c"), Color("5e5048"), Color("7a4a2a")]
const FACE := [Color("e8c8a0"), Color("f0d4b0"), Color("d8b08a"), Color("f2dcc0"), Color("e0c0a8"), Color("ecc89c")]
const DARK := Color("2a1a14")
const BLACK := Color("111111")
const GOLD := Color("d9a14e")
const STEEL := Color("b8b8c0")
const FEATHER := Color("f6f2ea")

var _accent: Color
var _look: int
var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _tail: Node3D
var _last := Vector3.INF
var _stride := 0.0      # the walk cycle
var _swing := 0.0       # how far the legs swing now, eased in and out
var _time := 0.0

func _init(accent: Color, look: int) -> void:
	_accent = accent
	_look = look % FUR.size()
	scale = Vector3.ONE * SCALE
	_build()

func hat_color() -> Color:
	return _accent

func ring_color() -> Color:
	return _accent

func leg_swing() -> float:
	return _legs[0].rotation.x

func hand_height() -> float:
	return (_arms[0].global_transform * Vector3(0, -0.43, 0)).y

# Called every frame with where the 2D crew member has put this monkey.
func animate(delta: float, carrying: bool) -> void:
	_time += delta
	var moved := position - _last if _last != Vector3.INF else Vector3.ZERO
	_last = position
	moved.y = 0.0
	var walking := delta > 0.0 and moved.length() / delta > WALK_SPEED
	if walking:
		rotation.y = lerp_angle(rotation.y, atan2(moved.x, moved.z), minf(1.0, TURN * delta))
		_stride += STRIDE * delta
	_swing = move_toward(_swing, 0.6 if walking else 0.0, 4.0 * delta)
	var s := sin(_stride) * _swing
	_legs[0].rotation.x = s
	_legs[1].rotation.x = -s
	for i in 2:
		if carrying:   # both hands up over the head, holding the load
			_arms[i].rotation = Vector3(-(PI - 0.15), 0, 0)
		else:
			_arms[i].rotation = Vector3((1 - 2 * i) * -s * 0.8, 0, (1 - 2 * i) * 0.12)
	_body.position.y = absf(sin(_stride)) * 0.06 * _swing / 0.6
	_tail.rotation = Vector3(sin(_time * 1.3 + _look * 2) * 0.12, 0, sin(_time * 2.2 + _look) * 0.25 + s * 0.3)

func _build() -> void:
	var fur: Color = FUR[_look]
	var face: Color = FACE[_look]
	var vest := _accent.darkened(0.3)
	# the ring on the deck, outside the body so it doesn't bob
	var ring := MeshKit.begin()
	MeshKit.torus(ring, Vector3(0, 0.02, 0), 0.4 / SCALE, 0.04, _accent, Basis.IDENTITY, 24)
	_add(self, ring)
	_body = Node3D.new()
	add_child(_body)

	# short bowed legs with big hand-like feet; a peg leg for one of them
	for side in [-1, 1]:
		var hip := _pivot(_body, Vector3(side * 0.1, 0.3, 0))
		var st := MeshKit.begin()
		if _look == 3 and side > 0:
			MeshKit.lathe(st, Vector3(0, -0.3, 0), PackedVector2Array([Vector2(0.022, 0), Vector2(0.03, 0.3)]), 6, Color("6b4228"))
		else:
			MeshKit.lathe(st, Vector3(0, -0.22, 0), PackedVector2Array([Vector2(0.05, 0), Vector2(0.06, 0.22)]), 8, fur, Basis(Vector3.BACK, side * 0.15))
			MeshKit.blob(st, Vector3(side * 0.02, -0.26, 0.05), Vector3(0.07, 0.04, 0.11), face)
		_add(hip, st)
		_legs.append(hip)

	# a round body with a pale belly, a waistcoat in the player's colour and a sash
	var st := MeshKit.begin()
	MeshKit.blob(st, Vector3(0, 0.5, 0), Vector3(0.2, 0.25, 0.18), fur)
	MeshKit.lathe(st, Vector3(0, 0.42, 0), PackedVector2Array([Vector2(0.205, 0), Vector2(0.17, 0.24)]), 14, vest, Basis.from_scale(Vector3(1, 1, 0.92)), PackedColorArray(), false)
	MeshKit.blob(st, Vector3(0, 0.47, 0.1), Vector3(0.13, 0.17, 0.12), face)
	MeshKit.torus(st, Vector3(0, 0.38, 0), 0.19, 0.028, Color("8e2a1e") if _look % 2 == 0 else Color("1e1a16"), Basis.from_scale(Vector3(1, 1, 0.9)), 16)

	# the head: a furry dome, a heart-shaped face, a muzzle and big ears
	var head := Transform3D(Basis.from_scale(Vector3.ONE * 1.22), Vector3(0, 0.9, 0))
	var h := func(at: Vector3) -> Vector3: return head * at
	var hb := head.basis
	MeshKit.blob(st, h.call(Vector3.ZERO), Vector3(0.16, 0.15, 0.15), fur, hb)
	for x in [-0.045, 0.045]:
		MeshKit.blob(st, h.call(Vector3(x, 0.02, 0.09)), Vector3(0.065, 0.075, 0.06), face, hb)
	MeshKit.blob(st, h.call(Vector3(0, -0.045, 0.11)), Vector3(0.085, 0.06, 0.06), face, hb)
	for x in [-0.022, 0.022]:
		MeshKit.blob(st, h.call(Vector3(x, -0.03, 0.168)), Vector3(0.01, 0.008, 0.008), DARK, hb, 3, 6)
	if _look == 1 or _look == 4:   # an eyepatch on a strap
		MeshKit.box(st, h.call(Vector3(0, 0.04, 0.1)), Vector3(0.34, 0.022, 0.02), BLACK, hb * Basis(Vector3.BACK, 0.35))
		MeshKit.blob(st, h.call(Vector3(0.045, 0.03, 0.145)), Vector3(0.035, 0.035, 0.01), BLACK, hb, 3, 8)
		MeshKit.blob(st, h.call(Vector3(-0.045, 0.03, 0.142)), Vector3(0.016, 0.018, 0.01), BLACK, hb, 3, 6)
	else:
		for x in [-0.045, 0.045]:
			MeshKit.blob(st, h.call(Vector3(x, 0.03, 0.142)), Vector3(0.016, 0.018, 0.01), BLACK, hb, 3, 6)
	for side in [-1, 1]:
		MeshKit.blob(st, h.call(Vector3(side * 0.16, 0.02, -0.01)), Vector3(0.03, 0.07, 0.065), fur, hb)
		MeshKit.blob(st, h.call(Vector3(side * 0.172, 0.02, 0)), Vector3(0.015, 0.05, 0.045), face, hb)
	if _look == 2 or _look == 5:   # a gold earring
		MeshKit.torus(st, h.call(Vector3(0.18, -0.05, 0)), 0.02, 0.006, GOLD, hb * Basis(Vector3.BACK, PI / 2), 8)

	# the tricorn carries identity from above: gold lace under a three-cornered brim in the player's colour
	var hat := head * Transform3D(Basis.from_scale(Vector3.ONE * 0.9), Vector3(0, 0.11, 0))
	var corners := hat.basis * Basis(Vector3.UP, PI / 6)
	MeshKit.cylinder(st, hat * Vector3(0, -0.025, 0), 0.32, 0.05, 3, GOLD, corners)
	MeshKit.cylinder(st, hat * Vector3(0, -0.015, 0), 0.29, 0.07, 3, _accent, corners)
	MeshKit.lathe(st, hat * Vector3(0, 0.03, 0), PackedVector2Array([Vector2(0.13, 0), Vector2(0.1, 0.12)]), 12, _accent, hat.basis)
	if _look == 0 or _look == 3:   # a feather
		MeshKit.lathe(st, hat * Vector3(-0.12, 0.17, -0.05), PackedVector2Array([Vector2(0.03, -0.17), Vector2(0, 0.17)]), 6, FEATHER, hat.basis * Basis(Vector3.BACK, 0.9))
	_add(_body, st)

	# long arms that hang nearly to the deck; a hook for one of them
	for side in [-1, 1]:
		var shoulder := _pivot(_body, Vector3(side * 0.2, 0.64, 0))
		var arm := MeshKit.begin()
		MeshKit.lathe(arm, Vector3(0, -0.4, 0), PackedVector2Array([Vector2(0.04, 0), Vector2(0.045, 0.4)]), 8, fur)
		if _look == 4 and side < 0:
			MeshKit.torus(arm, Vector3(0, -0.46, 0.02), 0.055, 0.012, STEEL, Basis(Vector3.RIGHT, PI / 2), 10)
		else:
			MeshKit.blob(arm, Vector3(0, -0.43, 0), Vector3(0.05, 0.05, 0.05), face)
		_add(shoulder, arm)
		_arms.append(shoulder)

	# a curled tail on its own pivot, so it can sway
	_tail = _pivot(_body, Vector3(0, 0.36, -0.15))
	var points: Array[Vector3] = []
	for k in 11:
		var u := k / 10.0
		points.append(Vector3(0, u * 0.4, -0.05 - sin(u * PI / 2) * 0.2))
	var f := 0.3
	while f <= PI * 1.6:
		points.append(Vector3(0, 0.4 + sin(f) * 0.08, -0.17 - cos(f) * 0.08))
		f += 0.3
	var tail := MeshKit.begin()
	for k in points.size() - 1:
		MeshKit.strut(tail, points[k], points[k + 1], 0.045, fur)
	_add(_tail, tail)

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = at
	parent.add_child(p)
	return p

func _add(parent: Node3D, st: SurfaceTool) -> void:
	var m := MeshInstance3D.new()
	m.mesh = MeshKit.commit(st)
	parent.add_child(m)
