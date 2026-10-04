extends CanvasLayer

@export var enemy: EnemyShip

@onready var _enemy_hull: ProgressBar = $EnemyHull

func _process(_delta: float) -> void:
	if enemy and enemy.max_hull_hp > 0.0:
		_enemy_hull.value = enemy.hull_hp / enemy.max_hull_hp * 100.0
