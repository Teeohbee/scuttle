extends CanvasLayer

@onready var _lines: VBoxContainer = $Lines

func push(text: String) -> void:
	var label := Label.new()
	label.text = text
	_lines.add_child(label)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
