extends CanvasLayer

const FONT_SIZE := 8

@onready var _lines: VBoxContainer = $Lines

func push(text: String) -> void:
	var label := Label.new()
	label.text = text
	# The viewport is only 360px tall. Godot's default 16px label puts three
	# messages across a quarter of the screen, straight over the ship.
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	_lines.add_child(label)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
