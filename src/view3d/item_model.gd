class_name ItemModel
extends Node3D
# Something a crab carries, standing on its base: a powder keg, a stack of shot, a pair of planks,
# or a bucket, full or empty. Each kind keeps its 2D colour, so the two views read the same.

const COLORS := {
	Carryable.Kind.POWDER: Color(0.45, 0.2, 0.15),
	Carryable.Kind.SHOT: Color(0.15, 0.15, 0.17),
	Carryable.Kind.PLANK: Color(0.72, 0.54, 0.31),
	Carryable.Kind.BUCKET_WATER: Color(0.35, 0.65, 0.88),
	Carryable.Kind.BUCKET_EMPTY: Color(0.5, 0.4, 0.3),
}

const ROPE := Color("b89a6a")
const SCALE := 1.4   # bigger than life, so you can tell at a glance what's being carried

static var _meshes := {}   # kind -> mesh, shared by every item of that kind

var _kind := -1
var _shown := MeshInstance3D.new()

func _init() -> void:
	_shown.scale = Vector3.ONE * SCALE
	add_child(_shown)

func show_kind(kind: Carryable.Kind) -> void:
	if kind == _kind:
		return
	_kind = kind
	if not _meshes.has(kind):
		_meshes[kind] = _build(kind)
	_shown.mesh = _meshes[kind]

func kind() -> int:
	return _kind

func has_water() -> bool:
	return _kind == Carryable.Kind.BUCKET_WATER

func shown() -> MeshInstance3D:
	return _shown

static func _build(kind: Carryable.Kind) -> ArrayMesh:
	var st := MeshKit.begin()
	var color: Color = COLORS[kind]
	match kind:
		Carryable.Kind.POWDER:
			MeshKit.barrel(st, Vector3.ZERO, 0.17, 0.34, color, DeckDresser.IRON)
			MeshKit.cylinder(st, Vector3(0.07, 0.335, 0), 0.025, 0.03, 5, DeckDresser.BRASS)   # the bung
		Carryable.Kind.SHOT:
			for i in 3:
				var a := TAU * i / 3.0
				MeshKit.ball(st, Vector3(cos(a) * 0.115, 0.1, sin(a) * 0.115), 0.1, color)
			MeshKit.ball(st, Vector3(0, 0.25, 0), 0.1, color)
		Carryable.Kind.PLANK:
			MeshKit.box(st, Vector3(0, 0.03, 0), Vector3(0.68, 0.06, 0.18), color)
			MeshKit.box(st, Vector3(0.03, 0.09, 0.02), Vector3(0.6, 0.06, 0.16), color.darkened(0.12), Basis(Vector3.UP, 0.12))
			for x in [-0.29, 0.29]:
				MeshKit.box(st, Vector3(x, 0.061, 0), Vector3(0.03, 0.005, 0.12), DeckDresser.DARK)   # sawn ends' grain
		Carryable.Kind.BUCKET_WATER, Carryable.Kind.BUCKET_EMPTY:
			_bucket(st, COLORS[Carryable.Kind.BUCKET_EMPTY], kind == Carryable.Kind.BUCKET_WATER)
	return MeshKit.commit(st)

# Staves taper out to an open rim, with two iron hoops and a rope handle over the top.
static func _bucket(st: SurfaceTool, wood: Color, full: bool) -> void:
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(0.13, 0), Vector2(0.16, 0.26), Vector2(0.14, 0.26), Vector2(0.115, 0.03)])
	var inside := wood.darkened(0.35)
	MeshKit.lathe(st, Vector3.ZERO, profile, 10, wood, Basis.IDENTITY, PackedColorArray([wood, wood, DeckDresser.LIGHT, inside]))
	for h in [0.05, 0.21]:
		MeshKit.torus(st, Vector3(0, h, 0), 0.13 + h * 0.115, 0.012, DeckDresser.IRON, Basis.IDENTITY, 10)
	MeshKit.strut(st, Vector3(-0.15, 0.25, 0), Vector3(-0.06, 0.4, 0), 0.02, ROPE)
	MeshKit.strut(st, Vector3(-0.06, 0.4, 0), Vector3(0.06, 0.4, 0), 0.02, ROPE)
	MeshKit.strut(st, Vector3(0.06, 0.4, 0), Vector3(0.15, 0.25, 0), 0.02, ROPE)
	if full:
		MeshKit.cylinder(st, Vector3(0, 0.2, 0), 0.142, 0.02, 10, COLORS[Carryable.Kind.BUCKET_WATER])
