extends Node

signal won
signal lost(reason: String)

var settled: bool = false

var invulnerable: bool = false

func reset() -> void:
	settled = false

func win() -> void:
	if settled:
		return
	settled = true
	won.emit()

func lose(reason: String) -> void:
	if settled or invulnerable:
		return
	settled = true
	lost.emit(reason)
