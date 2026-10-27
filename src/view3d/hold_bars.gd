class_name HoldBars
extends Node2D
# The supply stations' pick-up bars, drawn flat over the 3D like the 2D ones, so they stay as crisp and
# readable. Each sits a little above its station's model, wherever the camera puts that on screen.

const ABOVE_MODEL := 0.3   # metres between the top of a station's model and its bar
const BACKGROUND := Color(0, 0, 0, 0.6)
const FILL := Color.WHITE

var _view: View3D
var _shown: Array[Dictionary] = []   # {progress, position}: what was drawn last frame

func _init(view: View3D) -> void:
	_view = view

func update() -> void:
	_shown.clear()
	for station in get_tree().get_nodes_in_group("stations"):
		if not station.has_method("hold_progress") or station.hold_progress() <= 0.0:
			continue
		var model := _view.mirror_of(station) as StationModel
		if model == null:
			continue
		var top := model.global_transform * Vector3(0, model.body_aabb().end.y + ABOVE_MODEL, 0)
		var size: Vector2 = station.BAR_SIZE
		_shown.append({progress = station.hold_progress(), position = on_screen(top) - Vector2(size.x / 2.0, size.y), size = size})
	queue_redraw()

# Where a 3D point lands on screen, in the game's 640x360 units.
func on_screen(point: Vector3) -> Vector2:
	return _view.camera().unproject_position(point) * _view.drawn_size() / Vector2(_view.render_size())

func shown() -> Array[Dictionary]:
	return _shown

func _draw() -> void:
	for bar in _shown:
		var at: Vector2 = bar.position.round()
		draw_rect(Rect2(at, bar.size), BACKGROUND)
		draw_rect(Rect2(at, Vector2(bar.size.x * bar.progress, bar.size.y)), FILL)
