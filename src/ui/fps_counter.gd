extends CanvasLayer
# Frames per second in the top-right corner, toggled with F3 (toggle_fps). It shows the average and the
# slowest frame over the last half second, since a hitch hides in an average. Hidden, it does nothing.

const SAMPLE := 0.5   # seconds between readings

var _label := Label.new()
var _elapsed := 0.0
var _frames := 0
var _worst := 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # still counts while the game is paused
	_label.position = Vector2(540, 4)
	_label.size = Vector2(96, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_show(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps"):
		toggle()

func toggle() -> void:
	_show(not visible)

func text() -> String:
	return _label.text

func _show(on: bool) -> void:
	visible = on
	set_process(on)
	_label.text = ""
	_elapsed = 0.0
	_frames = 0
	_worst = 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _elapsed >= SAMPLE:
		_label.text = "%d FPS  %d ms" % [roundi(_frames / _elapsed), roundi(_worst * 1000.0)]
		_label.modulate = Color.WHITE if _worst < 1.0 / 50.0 else Color(1, 0.6, 0.3)
		_elapsed = 0.0
		_frames = 0
		_worst = 0.0
