class_name EnemyShip
extends Node2D

signal fired
signal broadside_landed

const INTERVAL := 4.0
const JITTER := 2.0
const SHOT_FLIGHT := 0.9

@export var max_hull_hp := 100.0
var hull_hp := 0.0
var _sunk := false

@onready var _cadence: Timer = $Cadence

func _ready() -> void:
	hull_hp = max_hull_hp
	_cadence.timeout.connect(_on_cadence_timeout)
	_roll_next_cadence()

func _roll_next_cadence() -> void:
	_cadence.start(INTERVAL + randf() * JITTER)

func _on_cadence_timeout() -> void:
	if _sunk:
		return
	fired.emit()
	_roll_next_cadence()
	await get_tree().create_timer(SHOT_FLIGHT).timeout
	if not _sunk:
		broadside_landed.emit()

func take_damage(amount: float) -> void:
	if _sunk:
		return
	hull_hp = max(0.0, hull_hp - amount)
	if hull_hp <= 0.0:
		_sunk = true
		GameState.win()
