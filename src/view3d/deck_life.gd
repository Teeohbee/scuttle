class_name DeckLife
extends Node3D
# Life on deck that isn't gameplay (look book Volume V): the wheel and binnacle on the quarterdeck, the
# flag at the stern, the bell at the bow, the parrot on the mainmast top, rats along the rail and the
# jolly boat towed astern. It reads only where the View3D put the deck, and moves only
# when the view calls update(), which it does only while it's in 3D.

const FLAG_STRIPS := 8
const FLAG_SIZE := Vector2(1.8, 1.2)
const BRASS := Color("c8962e")
const RAT_SPEED := 2.4

var _wheel: Node3D
var _binnacle: Node3D
var _flag: Node3D
var _flag_strips: Array[Node3D] = []
var _bell: Node3D
var _parrot: Node3D
var _parrot_head: Node3D
var _rats: Array[Node3D] = []
var _boat: Node3D
var _rng := RandomNumberGenerator.new()

func _init(view: View3D) -> void:
	var r := view.deck_rect()
	var mid := r.get_center().y
	var qd := View3D.QUARTERDECK_HEIGHT
	var st := MeshKit.begin()   # everything that stands still

	# the wheel on two posts, facing forward, with the binnacle in front of it
	var helm := Vector3(view.quarterdeck_start() + 1.6, qd, mid)
	for z in [-0.25, 0.25]:
		MeshKit.box(st, helm + Vector3(0.12, 0.47, z), Vector3(0.12, 0.95, 0.1), DeckDresser.DARK)
	_wheel = _node(helm + Vector3(0, 0.95, 0))
	var wheel := MeshKit.begin()
	var axle := Basis(Vector3.BACK, PI / 2)   # the wheel turns about the fore-and-aft axis
	MeshKit.torus(wheel, Vector3.ZERO, 0.48, 0.035, DeckDresser.LIGHT, axle, 24)
	for k in 8:
		var a := TAU * k / 8
		MeshKit.strut(wheel, Vector3.ZERO, Vector3(0, cos(a), sin(a)) * 0.66, 0.04, DeckDresser.MID)
	MeshKit.cylinder(wheel, Vector3(-0.07, 0, 0), 0.09, 0.14, 10, BRASS, axle)
	_mesh(_wheel, wheel)
	_binnacle = _node(Vector3(view.quarterdeck_start() + 0.9, qd, mid))
	var binnacle := MeshKit.begin()
	MeshKit.lathe(binnacle, Vector3.ZERO, PackedVector2Array([Vector2(0, 0), Vector2(0.16, 0), Vector2(0.18, 0.5),
		Vector2(0.22, 0.6), Vector2(0.14, 0.75), Vector2(0, 0.78)]), 10, BRASS)
	_mesh(_binnacle, binnacle)

	# the flag: a staff at the stern, and a black flag in strips that pass a wave down its length
	var staff := Vector3(r.end.x - 0.1, qd, mid)
	MeshKit.lathe(st, staff, PackedVector2Array([Vector2(0.06, 0), Vector2(0.05, 3.4)]), 8, DeckDresser.DARK)
	_flag = _node(staff + Vector3(0.05, 2.7, 0))
	var material := StandardMaterial3D.new()
	material.albedo_texture = _skull_and_bones()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var width := FLAG_SIZE.x / FLAG_STRIPS
	var parent := _flag
	for k in FLAG_STRIPS:
		var strip := Node3D.new()
		strip.position = Vector3(width if k > 0 else 0.0, 0, 0)
		parent.add_child(strip)
		var cloth := SurfaceTool.new()
		cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
		cloth.set_normal(Vector3.BACK)
		var u0 := float(k) / FLAG_STRIPS
		var u1 := float(k + 1) / FLAG_STRIPS
		var h := FLAG_SIZE.y / 2.0
		for v in [[0.0, u0, h, 0.0], [width, u1, h, 0.0], [width, u1, -h, 1.0], [0.0, u0, h, 0.0], [width, u1, -h, 1.0], [0.0, u0, -h, 1.0]]:
			cloth.set_uv(Vector2(v[1], v[3]))
			cloth.add_vertex(Vector3(v[0], v[2], 0))
		var m := MeshInstance3D.new()
		m.mesh = cloth.commit()
		m.material_override = material
		strip.add_child(m)
		_flag_strips.append(strip)
		parent = strip

	# the bell in its belfry at the bow
	var bow := Vector3(r.position.x - 0.6, 0, mid)
	for z in [-0.35, 0.35]:
		MeshKit.box(st, bow + Vector3(0, 0.5, z), Vector3(0.1, 1.0, 0.1), DeckDresser.DARK)
	MeshKit.box(st, bow + Vector3(0, 1.0, 0), Vector3(0.12, 0.1, 0.84), DeckDresser.DARK)
	_bell = _node(bow + Vector3(0, 0.95, 0))
	var bell := MeshKit.begin()
	MeshKit.lathe(bell, Vector3(0, -0.36, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0), Vector2(0.16, 0.06),
		Vector2(0.12, 0.28), Vector2(0.04, 0.36), Vector2(0.02, 0.36)]), 14, BRASS)
	_mesh(_bell, bell)

	# the parrot, on the rail of the mainmast's fighting top
	var masts := view.dresser().masts()
	if not masts.is_empty():
		masts.sort()
		_build_parrot(view.cell_centre(masts[masts.size() / 2]) + Vector3(0.2, DeckDresser.TOP_HEIGHT + 0.47, 0.52))

	# rats: one on each of the three longest runs of rail between the gun ports
	_rng.seed = 7
	var runs := _rail_runs(view, r)
	runs.sort_custom(func(a, b): return a.y - a.x > b.y - b.x)
	for k in mini(3, runs.size()):
		_build_rat(runs[k])

	# the jolly boat, towed astern on a line from the taffrail
	_build_jolly_boat(Vector3(r.end.x + 2.6, -0.55, mid + 0.6), Vector3(r.end.x + 0.3, qd + 0.4, mid))

	var still := MeshInstance3D.new()
	still.mesh = MeshKit.commit(st)
	add_child(still)

func wheel() -> Node3D:
	return _wheel

func binnacle() -> Node3D:
	return _binnacle

func flag() -> Node3D:
	return _flag

func flag_tip() -> Node3D:
	return _flag_strips.back()

func bell() -> Node3D:
	return _bell

func parrot() -> Node3D:
	return _parrot

func parrot_head() -> Node3D:
	return _parrot_head

func rats() -> Array[Node3D]:
	return _rats

func jolly_boat() -> Node3D:
	return _boat

func update(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_wheel.rotation.x = sin(t * 0.4) * 0.6 + sin(t * 0.13) * 0.4   # the helmsman nudging her course
	_bell.rotation.z = sin(t * 1.1) * 0.15
	for k in _flag_strips.size():
		_flag_strips[k].rotation.y = sin(t * 3.0 - k * 0.7) * (0.12 + k * 0.03)
	if _parrot:   # looks about in jerks, with a twitch, and bobs now and then
		_parrot_head.rotation.y = sin(floorf(t / 1.1) * 2.7) * 1.0 + sin(t * 5.0) * 0.05
		_parrot.position.y = _parrot.get_meta("perch") + maxf(0.0, sin(t * 2.3)) ** 8 * 0.04
	_boat.position.y = _boat.get_meta("float") + sin(t * 0.9) * 0.05 + sin(t * 2.3) * 0.02
	_boat.rotation = Vector3(sin(t * 0.7) * 0.04, 0.12 + sin(t * 0.3) * 0.08, sin(t * 1.1) * 0.05)
	for rat in _rats:   # dash to a spot along the run, sit a while, dash again
		var run: Vector3 = rat.get_meta("run")   # x from, x to, rail z
		var pause: float = rat.get_meta("pause") - delta
		var goal: float = rat.get_meta("goal")
		if pause > 0.0:
			rat.set_meta("pause", pause)
			continue
		rat.position.x = move_toward(rat.position.x, goal, RAT_SPEED * delta)
		rat.rotation.y = PI / 2 if goal > rat.position.x else -PI / 2
		if is_equal_approx(rat.position.x, goal):
			rat.set_meta("goal", _rng.randf_range(run.x, run.y))
			rat.set_meta("pause", _rng.randf_range(0.4, 2.5))

# Green with a red head and long blue and red tail feathers, facing out over the deck.
func _build_parrot(perch: Vector3) -> void:
	_parrot = _node(perch)
	_parrot.set_meta("perch", perch.y)
	_parrot.rotation.y = PI / 2
	var body := MeshKit.begin()
	MeshKit.blob(body, Vector3(0, 0.12, 0), Vector3(0.07, 0.11, 0.08), Color("2e9a3a"), Basis(Vector3.RIGHT, 0.25))
	for side in [-1, 1]:
		MeshKit.blob(body, Vector3(side * 0.06, 0.12, -0.01), Vector3(0.02, 0.08, 0.06), Color("1f6e8e"), Basis(Vector3.RIGHT, 0.25))
	for k in 3:
		MeshKit.strut(body, Vector3(0, 0.05, -0.05), Vector3((k - 1) * 0.03, -0.12, -0.16), 0.025, [Color("1f6e8e"), Color("c8342a"), Color("1f6e8e")][k])
	MeshKit.box(body, Vector3(0, 0.0, 0.01), Vector3(0.08, 0.02, 0.02), Color("2a2a2a"))   # feet on the rail
	_mesh(_parrot, body)
	_parrot_head = Node3D.new()
	_parrot_head.position = Vector3(0, 0.24, 0.02)
	_parrot.add_child(_parrot_head)
	var head := MeshKit.begin()
	MeshKit.blob(head, Vector3.ZERO, Vector3(0.06, 0.06, 0.065), Color("c8342a"))
	MeshKit.lathe(head, Vector3(0, -0.01, 0.05), PackedVector2Array([Vector2(0.025, 0), Vector2(0, 0.06)]), 6, Color("e8c860"), Basis(Vector3.RIGHT, PI / 2 + 0.4))
	for side in [-1, 1]:
		MeshKit.blob(head, Vector3(side * 0.045, 0.015, 0.025), Vector3(0.015, 0.015, 0.015), Color.WHITE, Basis.IDENTITY, 3, 6)
	_mesh(_parrot_head, head)

# The straight runs of bulwark rail, port and starboard, between the gun ports: (x from, x to, z).
func _rail_runs(view: View3D, r: Rect2) -> Array[Vector3]:
	var runs: Array[Vector3] = []
	for z in [r.position.y - 0.25, r.end.y + 0.25]:
		var cuts: Array[float] = []
		for gap in view.bulwark_gaps():
			if absf(gap.y - z) < 0.5:
				cuts.append(gap.x)
		cuts.sort()
		var from := r.position.x + 2.2
		for x in cuts:
			if x - 0.65 > from + 1.0:
				runs.append(Vector3(from, x - 0.65, z))
			from = maxf(from, x + 0.65)
		if r.end.x - 1.0 > from + 1.0:
			runs.append(Vector3(from, r.end.x - 1.0, z))
	return runs

func _build_rat(run: Vector3) -> void:
	var rat := _node(Vector3(_rng.randf_range(run.x, run.y), View3D.BULWARK_HEIGHT + 0.07, run.z))
	rat.set_meta("run", run)
	rat.set_meta("goal", rat.position.x)
	rat.set_meta("pause", _rng.randf_range(0.0, 1.0))
	var fur := Color("5a5048")
	var st := MeshKit.begin()
	MeshKit.blob(st, Vector3(0, 0.05, 0), Vector3(0.05, 0.045, 0.09), fur)
	MeshKit.blob(st, Vector3(0, 0.06, 0.09), Vector3(0.035, 0.035, 0.05), fur)
	for side in [-1, 1]:
		MeshKit.blob(st, Vector3(side * 0.025, 0.095, 0.08), Vector3(0.015, 0.018, 0.006), Color("c89a90"), Basis.IDENTITY, 3, 6)
	MeshKit.strut(st, Vector3(0, 0.04, -0.08), Vector3(0, 0.02, -0.24), 0.012, Color("c89a90"))
	_mesh(rat, st)
	_rats.append(rat)

# A small open boat lying along the ship's wake, its painter running up to the taffrail.
func _build_jolly_boat(at: Vector3, taffrail: Vector3) -> void:
	_boat = _node(at)
	_boat.set_meta("float", at.y)
	var st := MeshKit.begin()
	var bowl := PackedVector2Array()
	for i in 5:
		var a := PI / 2 * i / 4
		bowl.append(Vector2(sin(a), -cos(a)))
	var shape := Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(0.6, 0.35, 1.5))   # long along x
	var hull := Color("8a3a2a")
	MeshKit.lathe(st, Vector3(0, 0.3, 0), bowl, 16, hull, shape, PackedColorArray([hull, hull, hull, hull, Color("4a2a1c")]))
	MeshKit.torus(st, Vector3(0, 0.31, 0), 1.0, 0.05, DeckDresser.OCHRE, shape, 20)
	for x in [-0.5, 0.2]:
		MeshKit.box(st, Vector3(x, 0.33, 0), Vector3(0.14, 0.04, 1.0), DeckDresser.LIGHT)
	MeshKit.strut(st, Vector3(-0.9, 0.36, 0.25), Vector3(0.9, 0.36, -0.1), 0.04, DeckDresser.LIGHT)   # a shipped oar
	MeshKit.strut(st, Vector3(-1.45, 0.33, 0), taffrail - at, 0.025, DeckDresser.ROPE)   # the painter
	_mesh(_boat, st)

# A white skull over crossed bones on black.
func _skull_and_bones() -> ImageTexture:
	var img := Image.create(64, 42, false, Image.FORMAT_RGB8)
	img.fill(Color("141210"))
	var bone := Color("efe6d2")
	for f in 37:
		for w in range(-1, 2):
			img.set_pixel(14 + f, 8 + int(f * 0.7) + w, bone)
			img.set_pixel(50 - f, 8 + int(f * 0.7) + w, bone)
	for y in 42:
		for x in 64:
			if Vector2(x - 32, (y - 15) * 1.1).length() < 8.5 or (x >= 27 and x <= 37 and y >= 20 and y <= 25):
				img.set_pixel(x, y, bone)
			if Vector2(x - 29, y - 14).length() < 2.3 or Vector2(x - 35, y - 14).length() < 2.3:
				img.set_pixel(x, y, Color("141210"))
	return ImageTexture.create_from_image(img)

func _node(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	return n

func _mesh(parent: Node3D, st: SurfaceTool) -> void:
	var m := MeshInstance3D.new()
	m.mesh = MeshKit.commit(st)
	parent.add_child(m)
