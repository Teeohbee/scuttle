extends CanvasLayer

@onready var _label: Label = $Overlay/Label
@onready var _hint: Label = $Overlay/Hint

func _ready() -> void:
	hide()
	GameState.won.connect(_on_won)
	GameState.lost.connect(_on_lost)

func _on_won() -> void:
	_label.text = "VICTORY"
	_reveal()

func _on_lost(reason: String) -> void:
	_label.text = "DEFEAT - %s" % reason
	_reveal()

func _reveal() -> void:
	_hint.text = "Press R to sail again"
	show()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		restart()

func restart() -> void:
	# GameState outlives the scene, so it has to be told the battle is over
	# BEFORE the new one loads, or win()/lose() stay locked out.
	GameState.reset()
	get_tree().reload_current_scene()
