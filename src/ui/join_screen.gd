extends Control

func _ready() -> void:
	_refresh()

func _physics_process(_delta: float) -> void:
	for device_id in PlayerRegistry.connected_devices():
		if PlayerRegistry.is_join_just_pressed(device_id) and not PlayerRegistry.is_joined(device_id):
			PlayerRegistry.join(device_id)
			_refresh()
	if PlayerRegistry.players().size() >= 2:
		for player in PlayerRegistry.players():
			if PlayerRegistry.is_interact_just_pressed(player.device_id):
				get_tree().change_scene_to_file("res://src/ship/deck.tscn")
				return

func _refresh() -> void:
	var joined_numbers := {}
	for p in PlayerRegistry.players():
		joined_numbers[p.number] = true
	for i in range(PlayerRegistry.MAX_PLAYERS):
		var slot := $Slots.get_child(i)
		slot.get_node("Layout/Status").text = "JOINED" if joined_numbers.has(i + 1) else "PRESS TO JOIN"
