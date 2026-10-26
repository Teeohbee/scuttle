class_name PirateCrab
extends Node3D
# A pirate crab, ported part for part from the "Pirate crabs on deck" artifact
# (https://claude.ai/artifact/7enQMpqt7MvcxetzHiQVtz): a low-poly crab with a faceted six-sided shell,
# big cartoon eyes on stalks, two big angular claws and three pointed legs a side, dressed for its role.
# The shell is the role's natural colour; the hat and the deck ring carry the player's colour so
# players can find themselves from above. It scuttles sideways. Built from MeshKit on hip, shoulder
# and pincer pivots; animate() drives them from how the crab moved since the last frame, so it only
# needs its 2D crew member's position.

const SCALE := 1.2
const SHELL_TOP := 0.51 * SCALE   # metres, the top of the carapace
const HELD_HEIGHT := 0.86         # metres: where a carried item rides, between the raised claws
const WALK_SPEED := 0.3           # m/s: slower than this is standing still
const STRIDE := 18.0              # leg steps, in radians per second of walking
const TURN := 12.0                # how quickly it turns side on to where it's going
const LEG_YAW := 0.3              # radians each leg swings forward and back
const LEG_LIFT := 0.4             # radians each leg lifts as it steps

# Each role's shell colour and face. brows are each brow's tilt for the [left, right] eyes (positive
# is stern, negative is cheerful), brow_y nudges them up or down, and lids close each eye from the
# top (0 open, 1 squint).
const ROLES := [
	{key = "captain", name = "Captain", shell = Color("a65a4c"), brows = [0.38, 0.38], brow_y = -0.012, lids = [0.0, 0.0]},
	{key = "mate", name = "First mate", shell = Color("b47a56"), brows = [0.18, 0.18], brow_y = 0.0, lids = [0.0, 0.0]},
	{key = "bosun", name = "Bosun", shell = Color("7a6168"), brows = [0.3, 0.3], brow_y = -0.006, lids = [0.0, 0.0]},
	{key = "crewmate", name = "Crewmate", shell = Color("7b7f62"), brows = [0.0, 0.0], brow_y = 0.0, lids = [0.3, 0.3]},
	{key = "deckhand", name = "Deckhand", shell = Color("86705e"), brows = [-0.32, -0.32], brow_y = 0.014, lids = [0.0, 0.0]},
	{key = "lookout", name = "Lookout", shell = Color("b3a38c"), brows = [-0.25, 0.3], brow_y = 0.004, lids = [0.0, 0.6]},
]

const EYE_WHITE := Color("f4efe4")
const DARK := Color("2a1a14")
const BLACK := Color("111111")
const GOLD := Color("d9a14e")
const BRASS := Color("c8962e")
const FEATHER := Color("f6f2ea")
const STRIPE := Color("f6f2ea")
const CREAM := Color("f2dcc0")
const BELT := Color("4a2c18")
const DARK_WOOD := Color("6b4228")
const LIGHT_WOOD := Color("9a6a40")

var _accent: Color
var _role: Dictionary
var _body: Node3D
var _legs: Array[Node3D] = []
var _leg_base_yaw: Array[float] = []
var _leg_side: Array[float] = []
var _leg_phase: Array[float] = []
var _claws: Array[Node3D] = []
var _pincers: Array[Node3D] = []
var _eyes: Array[Vector3] = []
var _last_position := Vector3.INF
var _stride := 0.0      # the walk cycle
var _swing := 0.0       # how far the legs swing now, eased in and out
var _time := 0.0

func _init(accent: Color, role: int) -> void:
	_accent = accent
	_role = ROLES[role % ROLES.size()]
	scale = Vector3.ONE * SCALE
	_build()

func role_name() -> String:
	return _role.name

func hat_color() -> Color:
	return _accent

func ring_color() -> Color:
	return _accent

func leg_swing() -> float:
	return _legs[0].rotation.y - _leg_base_yaw[0]

# How high the left claw's palm is, in world space.
func claw_height() -> float:
	return (_claws[0].global_transform * Vector3(-0.14, 0.13, 0.29)).y

func vertex_count() -> int:
	var count := 0
	for mesh_instance in find_children("*", "MeshInstance3D", true, false):
		count += (mesh_instance as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	return count

# Called every frame with where the 2D crew member has put this crab.
func animate(delta: float, carrying: bool) -> void:
	_time += delta
	var moved := position - _last_position if _last_position != Vector3.INF else Vector3.ZERO
	_last_position = position
	moved.y = 0.0
	var walking := delta > 0.0 and moved.length() / delta > WALK_SPEED
	if walking:
		rotation.y = lerp_angle(rotation.y, _side_on_heading(atan2(moved.x, moved.z)), minf(1.0, TURN * delta))
		_stride += STRIDE * delta
	_swing = move_toward(_swing, 1.0 if walking else 0.0, 5.0 * delta)
	for leg_index in _legs.size():
		var step := _stride + _leg_phase[leg_index]
		_legs[leg_index].rotation.y = _leg_base_yaw[leg_index] + sin(step) * LEG_YAW * _swing
		_legs[leg_index].rotation.z = _leg_side[leg_index] * maxf(0.0, cos(step)) * LEG_LIFT * _swing
	_body.position.y = absf(sin(_stride)) * 0.025 * _swing + sin(_time * 2.0) * 0.004
	for claw_index in 2:
		var side := -1.0 if claw_index == 0 else 1.0
		if carrying:   # both claws up, holding the load
			_claws[claw_index].rotation = Vector3(-1.1, 0, side * 0.3)
		else:
			var bob := sin(_time * 1.6 + claw_index) * 0.05 - sin(_stride + claw_index * PI) * 0.1 * _swing
			var sway := side * (0.12 + sin(_time * 1.1 + claw_index * 2) * 0.04)
			_claws[claw_index].rotation = Vector3(-0.32 + bob, sway, 0)
		var snapping := sin(_time * 1.9 + claw_index * 2.4) > 0.86
		if carrying:
			_pincers[claw_index].rotation.x = 0.05
		elif snapping:
			_pincers[claw_index].rotation.x = 0.75
		else:
			_pincers[claw_index].rotation.x = 0.4

# Crabs walk sideways: face 90 degrees off the heading, whichever way needs less turning.
func _side_on_heading(heading: float) -> float:
	var left_flank_leads := heading - PI / 2
	var right_flank_leads := heading + PI / 2
	if absf(angle_difference(rotation.y, left_flank_leads)) < absf(angle_difference(rotation.y, right_flank_leads)):
		return left_flank_leads
	return right_flank_leads

func _build() -> void:
	var shell: Color = _role.shell
	var underside := shell.darkened(0.18)
	var limb := shell.darkened(0.06)
	var tip := shell.darkened(0.3)

	# the ring on the deck, outside the body so it doesn't bob
	var ring := MeshKit.begin()
	MeshKit.torus(ring, Vector3(0, 0.02, 0), 0.4 / SCALE, 0.04, _accent, Basis.IDENTITY, 24)
	_add(self, ring)
	_body = Node3D.new()
	add_child(_body)

	# three legs a side: up and out to the knee, then down to a point
	var leg_z := [0.05, -0.06, -0.16]
	var leg_yaw := [-0.25, 0.15, 0.55]
	for side in [-1, 1]:
		for k in 3:
			var hip := _pivot(_body, Vector3(side * 0.25, 0.29, leg_z[k]))
			_leg_base_yaw.append(side * leg_yaw[k])
			_leg_side.append(float(side))
			_leg_phase.append(((k + (0 if side > 0 else 1)) % 2) * PI)
			hip.rotation.y = side * leg_yaw[k]
			var st := MeshKit.begin()
			var knee := Vector3(side * 0.14, 0.11, 0)
			var foot := Vector3(side * 0.22, -0.29, 0)
			MeshKit.tube(st, Vector3.ZERO, knee, 0.056, 0.048, limb, 4)
			MeshKit.tube(st, knee, foot, 0.048, 0.006, limb, 4)
			_add(hip, st)
			_legs.append(hip)

	# the carapace: a six-sided faceted dome, pointed at the sides, squashed front to back
	var st := MeshKit.begin()
	var carapace := PackedVector2Array([Vector2(0.13, 0), Vector2(0.27, 0.07), Vector2(0.34, 0.15), Vector2(0.3, 0.21), Vector2(0.17, 0.27), Vector2(0, 0.29)])
	MeshKit.lathe(st, Vector3(0, 0.22, 0), carapace, 6, shell, Basis.from_scale(Vector3(1, 1, 0.74)), PackedColorArray([underside, underside, shell, shell, shell]))
	# mouth plates under the front edge
	for side in [-1, 1]:
		MeshKit.blob(st, Vector3(side * 0.035, 0.33, 0.215), Vector3(0.04, 0.05, 0.022), underside, Basis(Vector3.UP, side * 0.35), 2, 4)
	_build_eyes(st, limb, tip)
	_build_role_gear(st)
	_add(_body, st)
	_build_claws(shell, limb, tip)
	if _role.key == "lookout":   # a brass spyglass held up in the left claw
		var spyglass := MeshKit.begin()
		var profile := PackedVector2Array([Vector2(0.03, 0), Vector2(0.03, 0.16), Vector2(0.024, 0.16), Vector2(0.024, 0.3), Vector2(0.019, 0.3), Vector2(0.019, 0.4), Vector2(0.03, 0.41)])
		MeshKit.lathe(spyglass, Vector3(-0.14, 0.28, 0.12), profile, 8, BRASS, Basis(Vector3.RIGHT, PI / 2 - 0.25), PackedColorArray([DARK_WOOD, BRASS, BRASS, BRASS, BRASS, BRASS]))
		_add(_claws[0], spyglass)

# Big round cartoon eyes on stalks, with pupils tilted up toward the game camera, a shine, a brow
# resting on the eyeball and, for some roles, a lid that sets the mood.
func _build_eyes(st: SurfaceTool, limb: Color, tip: Color) -> void:
	var pupil_tilt := 0.45
	for side in [-1, 1]:
		var eye_index := 0 if side < 0 else 1
		var eye := Vector3(side * 0.105, 0.73, 0.15)
		MeshKit.tube(st, Vector3(side * 0.08, 0.46, 0.13), eye, 0.022, 0.018, limb, 4)
		var pupil_direction := Vector3(-side * 0.14, sin(pupil_tilt), cos(pupil_tilt)).normalized()
		MeshKit.ball(st, eye, 0.088, EYE_WHITE, 6, 14)
		MeshKit.blob(st, eye + pupil_direction * 0.068, Vector3(0.048, 0.058, 0.03), BLACK, Basis(Vector3.UP, -side * 0.14) * Basis(Vector3.RIGHT, -pupil_tilt), 4, 10)
		MeshKit.ball(st, eye + Vector3(-0.022, 0.06, 0.062), 0.013, Color.WHITE, 2, 6)
		var lid: float = _role.lids[eye_index]
		if lid > 0.0:
			var lid_angle := 0.55 + lid * 0.75
			var lid_profile := PackedVector2Array()
			for k in 5:
				var a := lid_angle * (1.0 - k / 4.0)
				lid_profile.append(Vector2(0.101 * sin(a), 0.101 * cos(a)))
			MeshKit.lathe(st, eye, lid_profile, 14, _role.shell, Basis(Vector3.RIGHT, 0.32))
		var brow_lift := 0.008 if lid > 0.0 else 0.0
		var brow_tilt: float = _role.brows[eye_index]
		var brow_at := Vector3(eye.x, eye.y + 0.084 + brow_lift + _role.brow_y, eye.z + 0.026)
		MeshKit.box(st, brow_at, Vector3(0.1, 0.024, 0.036), tip, Basis(Vector3.BACK, side * brow_tilt) * Basis(Vector3.RIGHT, 0.25))
		_eyes.append(eye)

# The claws: an angular arm and a big palm, a fixed upper finger and a lower one that opens.
func _build_claws(shell: Color, limb: Color, tip: Color) -> void:
	for side in [-1, 1]:
		var shoulder := _pivot(_body, Vector3(side * 0.22, 0.32, 0.14))
		shoulder.scale = Vector3.ONE * 1.3   # the claws are nearly as big as the shell
		var claw := MeshKit.begin()
		var elbow := Vector3(side * 0.13, 0.04, 0.06)
		var wrist := Vector3(side * 0.13, 0.1, 0.17)
		MeshKit.strut(claw, Vector3.ZERO, elbow, 0.065, limb)
		MeshKit.strut(claw, elbow, wrist, 0.075, limb)
		var palm := Vector3(wrist.x + side * 0.01, wrist.y + 0.03, wrist.z + 0.12)
		MeshKit.blob(claw, palm, Vector3(0.1, 0.13, 0.16), shell, Basis(Vector3.BACK, -side * 0.25), 3, 5)
		# the fixed upper finger curves forward and down to a point
		var finger_root := Vector3(palm.x, palm.y + 0.07, palm.z + 0.11)
		var finger_middle := Vector3(palm.x - side * 0.01, palm.y + 0.08, palm.z + 0.22)
		var finger_point := Vector3(palm.x - side * 0.03, palm.y + 0.01, palm.z + 0.31)
		MeshKit.tube(claw, finger_root, finger_middle, 0.06, 0.045, shell, 4)
		MeshKit.tube(claw, finger_middle, finger_point, 0.045, 0.006, shell, 4)
		var hinge := _pivot(shoulder, Vector3(palm.x, palm.y - 0.07, palm.z + 0.1))
		var lower_finger := MeshKit.begin()
		var knuckle := Vector3(-side * 0.02, 0.02, 0.12)
		MeshKit.tube(lower_finger, Vector3.ZERO, knuckle, 0.05, 0.035, tip, 4)
		MeshKit.tube(lower_finger, knuckle, Vector3(-side * 0.03, 0.07, 0.2), 0.035, 0.005, tip, 4)
		_add(hinge, lower_finger)
		_pincers.append(hinge)
		_add(shoulder, claw)
		_claws.append(shoulder)

# Each role's hat, in the player's colour, and its extras.
func _build_role_gear(st: SurfaceTool) -> void:
	var hat := Transform3D(Basis.from_scale(Vector3.ONE * 0.8), Vector3(0, 0.49, -0.09))
	var left_eye := _eyes[0]
	var right_eye := _eyes[1]
	match _role.key:
		"captain":
			_tricorn(st, hat)
			for side in [-1, 1]:   # gold epaulettes with a fringe
				var at := Vector3(side * 0.26, 0.47, 0.0)
				MeshKit.blob(st, at, Vector3(0.085, 0.026, 0.075), GOLD, Basis(Vector3.BACK, -side * 0.45), 3, 8)
				for fringe in range(-2, 3):
					var fringe_top := Vector3(at.x + side * 0.06, at.y - 0.03, at.z + fringe * 0.025)
					var fringe_end := Vector3(at.x + side * 0.08, at.y - 0.09, at.z + fringe * 0.025)
					MeshKit.strut(st, fringe_top, fringe_end, 0.012, GOLD)
		"mate":
			_bicorne(st, hat)
			MeshKit.torus(st, Vector3(0, 0.37, 0), 0.345, 0.026, BELT, Basis.from_scale(Vector3(1, 1, 0.75)), 12)   # a belt with a gold buckle
			MeshKit.box(st, Vector3(0, 0.37, 0.262), Vector3(0.08, 0.07, 0.02), GOLD)
			MeshKit.box(st, Vector3(0, 0.37, 0.266), Vector3(0.045, 0.035, 0.02), BELT)
		"bosun":
			_head_wrap(st, hat)
			_eyepatch(st, right_eye)
		"crewmate":
			_watch_cap(st, hat)
			MeshKit.tube(st, Vector3(0.03, 0.33, 0.235), Vector3(0.12, 0.31, 0.32), 0.012, 0.01, DARK_WOOD, 5)   # a clay pipe
			MeshKit.lathe(st, Vector3(0.13, 0.3, 0.33), PackedVector2Array([Vector2(0.025, 0), Vector2(0.034, 0.07)]), 7, LIGHT_WOOD)
			MeshKit.cylinder(st, Vector3(0.13, 0.365, 0.33), 0.026, 0.008, 7, DARK)
		"deckhand":
			_bandana(st, hat, false)
			var earring_at := Vector3(left_eye.x - 0.03, left_eye.y - 0.16, left_eye.z + 0.01)
			MeshKit.torus(st, earring_at, 0.035, 0.008, GOLD, Basis(Vector3.RIGHT, PI / 2), 10)
		"lookout":
			_bandana(st, hat, true)

# Gold lace under a three-cornered brim, and a feather.
func _tricorn(st: SurfaceTool, hat: Transform3D) -> void:
	var corners := hat.basis * Basis(Vector3.UP, PI / 6)
	MeshKit.cylinder(st, hat * Vector3(0, -0.025, 0), 0.32, 0.05, 3, GOLD, corners)
	MeshKit.cylinder(st, hat * Vector3(0, -0.015, 0), 0.29, 0.07, 3, _accent, corners)
	MeshKit.lathe(st, hat * Vector3(0, 0.03, 0), PackedVector2Array([Vector2(0.13, 0), Vector2(0.1, 0.12)]), 12, _accent, hat.basis)
	MeshKit.lathe(st, hat * Vector3(-0.12, 0.17, -0.05), PackedVector2Array([Vector2(0.03, -0.17), Vector2(0, 0.17)]), 6, FEATHER, hat.basis * Basis(Vector3.BACK, 0.9))

# A captain's bicorne worn athwartships, edged in gold, with a cockade.
func _bicorne(st: SurfaceTool, hat: Transform3D) -> void:
	MeshKit.blob(st, hat * Vector3(0, 0.08, 0), Vector3(0.27, 0.13, 0.1), _accent, hat.basis, 6, 14)
	MeshKit.blob(st, hat * Vector3(0, 0.08, 0), Vector3(0.28, 0.14, 0.08), GOLD, hat.basis, 6, 14)
	MeshKit.cylinder(st, hat * Vector3(0.1, 0.11, 0.085), 0.04, 0.025, 10, CREAM, hat.basis * Basis(Vector3.RIGHT, PI / 2))
	MeshKit.ball(st, hat * Vector3(0.1, 0.11, 0.115), 0.016, GOLD, 2, 5)

# Three twisted turns of cloth, with a gold jewel at the front.
func _head_wrap(st: SurfaceTool, hat: Transform3D) -> void:
	var dark_cloth := _accent.darkened(0.25)
	MeshKit.torus(st, hat * Vector3(0, 0.04, 0), 0.17, 0.055, _accent, hat.basis, 16)
	MeshKit.torus(st, hat * Vector3(0.01, 0.1, -0.01), 0.14, 0.05, dark_cloth, hat.basis * Basis(Vector3.BACK, 0.14), 16)
	MeshKit.torus(st, hat * Vector3(-0.01, 0.15, 0), 0.1, 0.045, _accent, hat.basis * Basis(Vector3.RIGHT, -0.12), 16)
	MeshKit.blob(st, hat * Vector3(0, 0.16, 0), Vector3(0.1, 0.06, 0.1), _accent, hat.basis, 4, 10)
	MeshKit.ball(st, hat * Vector3(0, 0.09, 0.21), 0.032, GOLD, 3, 6)

# A knitted watch cap with a rolled brim and a bobble.
func _watch_cap(st: SurfaceTool, hat: Transform3D) -> void:
	var cap_profile := PackedVector2Array([Vector2(0.18, 0), Vector2(0.17, 0.08), Vector2(0.12, 0.15), Vector2(0, 0.18)])
	MeshKit.torus(st, hat * Vector3(0, 0.03, 0), 0.18, 0.048, _accent.darkened(0.25), hat.basis, 18)
	MeshKit.lathe(st, hat * Vector3(0, 0.03, 0), cap_profile, 14, _accent, hat.basis)
	MeshKit.ball(st, hat * Vector3(0, 0.23, 0), 0.06, _accent.lightened(0.55), 3, 7)

# A cloth cap pulled tight, knotted at the back with two tails; dotted, or striped.
func _bandana(st: SurfaceTool, hat: Transform3D, striped: bool) -> void:
	var dark_cloth := _accent.darkened(0.25)
	var cap_profile := PackedVector2Array([Vector2(0.21, 0), Vector2(0.2, 0.06), Vector2(0.15, 0.12), Vector2(0.07, 0.15), Vector2(0, 0.16)])
	MeshKit.lathe(st, hat * Vector3(0, -0.02, 0), cap_profile, 14, _accent, hat.basis)
	if striped:
		MeshKit.torus(st, hat * Vector3(0, 0.03, 0), 0.208, 0.014, STRIPE, hat.basis, 16)
		MeshKit.torus(st, hat * Vector3(0, 0.1, 0), 0.17, 0.014, STRIPE, hat.basis, 16)
	else:
		for k in 7:
			var a := k * TAU / 7 + 0.3
			MeshKit.blob(st, hat * Vector3(cos(a) * 0.188, 0.07, sin(a) * 0.188), Vector3(0.028, 0.028, 0.028), STRIPE, hat.basis, 3, 6)
		MeshKit.blob(st, hat * Vector3(0, 0.145, 0), Vector3(0.03, 0.02, 0.03), STRIPE, hat.basis, 3, 6)
	MeshKit.blob(st, hat * Vector3(0.04, 0.05, -0.21), Vector3(0.055, 0.05, 0.045), dark_cloth, hat.basis, 4, 8)
	MeshKit.tube(st, hat * Vector3(0.04, 0.04, -0.22), hat * Vector3(0.13, -0.08, -0.29), 0.032, 0.012, dark_cloth, 6)
	MeshKit.tube(st, hat * Vector3(0.04, 0.04, -0.22), hat * Vector3(-0.03, -0.1, -0.28), 0.032, 0.012, dark_cloth, 6)

func _eyepatch(st: SurfaceTool, eye: Vector3) -> void:
	MeshKit.blob(st, Vector3(eye.x, eye.y + 0.028, eye.z + 0.076), Vector3(0.07, 0.066, 0.024), BLACK, Basis(Vector3.RIGHT, -0.4), 3, 8)
	MeshKit.torus(st, eye, 0.09, 0.009, BLACK, Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, PI / 2), 12)

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = at
	parent.add_child(p)
	return p

func _add(parent: Node3D, st: SurfaceTool) -> void:
	var m := MeshInstance3D.new()
	m.mesh = MeshKit.commit(st)
	parent.add_child(m)
