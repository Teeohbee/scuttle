extends Control

var _bots := false

func _ready() -> void:
	_refresh()

func _physics_process(_delta: float) -> void:
	for device_id in PlayerRegistry.connected_devices():
		if PlayerRegistry.is_join_just_pressed(device_id) and not PlayerRegistry.is_joined(device_id):
			PlayerRegistry.join(device_id)
			_refresh()
	if Input.is_action_just_pressed("toggle_bots"):
		_bots = not _bots
		_refresh()
	# With bots filling the empty seats, one person is enough to set sail.
	if PlayerRegistry.players().size() >= (1 if _bots else 2):
		for player in PlayerRegistry.players():
			if PlayerRegistry.is_interact_just_pressed(player.device_id):
				if _bots:
					PlayerRegistry.fill_with_bots()
				get_tree().change_scene_to_file("res://src/ship/deck.tscn")
				return

func _refresh() -> void:
	var joined_numbers := {}
	for p in PlayerRegistry.players():
		joined_numbers[p.number] = true
	for i in range(PlayerRegistry.MAX_PLAYERS):
		var slot := $Slots.get_child(i)
		var status := "JOINED" if joined_numbers.has(i + 1) else ("BOT" if _bots else "PRESS TO JOIN")
		slot.get_node("Layout/Status").text = status
	$Bots.text = "B / Y - BOTS: %s" % ("ON" if _bots else "OFF")
