extends CanvasLayer

@export var enemy: EnemyShip
@export var fire: FireHazard

@onready var _enemy_hull: ProgressBar = $EnemyHull
@onready var _fuse: Label = $Fuse

func _process(_delta: float) -> void:
	if enemy and enemy.max_hull_hp > 0.0:
		_enemy_hull.value = enemy.hull_hp / enemy.max_hull_hp * 100.0
	var left := fire.fuse_left() if fire else -1.0
	_fuse.visible = left >= 0.0 and not GameState.settled
	if _fuse.visible:
		_fuse.text = "MAGAZINE ALIGHT - %d" % ceili(left)
