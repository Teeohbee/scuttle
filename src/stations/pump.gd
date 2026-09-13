class_name Pump
extends Station

var manned: bool = false

func _physics_process(_delta: float) -> void:
	var user := _occupant()
	manned = user != null and PlayerRegistry.is_interact_pressed(user.device_id)

func _occupant() -> Node2D:
	for crew in get_tree().get_nodes_in_group("crew"):
		if crew_is_near(crew):
			return crew
	return null
