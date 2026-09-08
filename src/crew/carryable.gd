class_name Carryable
extends Node2D

enum Kind { POWDER, SHOT, PLANK, BUCKET_WATER, BUCKET_EMPTY }

# One AtlasTexture per Kind, in enum order. Set these in the Inspector -
# being able to tell what you're carrying at a glance is not optional.
@export var icons: Array[AtlasTexture] = []

@export var kind: Kind = Kind.POWDER
var held: bool = false

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("carryables")
	_refresh_icon()

func set_kind(next: Kind) -> void:
	kind = next
	_refresh_icon()

func _refresh_icon() -> void:
	if _sprite == null or int(kind) >= icons.size():
		return
	_sprite.texture = icons[int(kind)]

func pick_up(hold_point: Node2D) -> void:
	held = true
	get_parent().remove_child(self)
	hold_point.add_child(self)
	position = Vector2.ZERO

func drop(world: Node2D, at: Vector2) -> void:
	held = false
	get_parent().remove_child(self)
	world.add_child(self)
	global_position = at
