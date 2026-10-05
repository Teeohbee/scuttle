extends Node

const KEYBOARD_WASD := -1
const KEYBOARD_ARROWS := -2
# Bots press real Input Map actions on made-up pads, numbered from here so they
# never collide with a joypad Godot reports (those count up from 0).
const BOT_DEVICE_BASE := 100

const MAX_PLAYERS := 6
const ACCENT_COLORS: Array[Color] = [
	Color("e05252"), Color("4f8fe0"), Color("4fbf6b"),
	Color("e0c24f"), Color("b06fe0"), Color("e08a3d"),
]

const SCHEME_SUFFIX := {
	KEYBOARD_WASD: "wasd",
	KEYBOARD_ARROWS: "arrows"
}

const PAD_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down", "interact", "join"
]
const BOT_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "interact"]

var _players: Dictionary = {} # device_id -> { device_id, number, color, is_bot }

func _ready() -> void:
	for device_id in Input.get_connected_joypads():
		_bind_device(device_id)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		_bind_device(device_id)

func _bind_device(device_id: int) -> void:
	for action in PAD_ACTIONS:
		var template := "%s_pad" % action
		var per_device := "%s_pad%d" % [action, device_id]
		if InputMap.has_action(per_device):
			continue
		InputMap.add_action(per_device, InputMap.action_get_deadzone(template))
		for event in InputMap.action_get_events(template):
			var copy : InputEvent = event.duplicate()
			copy.device = device_id
			InputMap.action_add_event(per_device, copy)

func suffix(device_id: int) -> String:
	return SCHEME_SUFFIX.get(device_id, "pad%d" % device_id)

func has_device(device_id: int) -> bool:
	return InputMap.has_action("interact_%s" % suffix(device_id))

func connected_devices() -> Array:
	var out : Array = [KEYBOARD_WASD, KEYBOARD_ARROWS]
	out.append_array(Input.get_connected_joypads())
	return out

func move_vector(device_id: int) -> Vector2:
	if not has_device(device_id):
		return Vector2.ZERO
	var s := suffix(device_id)
	return Input.get_vector(
		"move_left_%s" % s, "move_right_%s" % s,
		"move_up_%s" % s, "move_down_%s" % s,
	)

func is_interact_pressed(device_id: int) -> bool:
	return has_device(device_id) and Input.is_action_pressed("interact_%s" % suffix(device_id))

func is_interact_just_pressed(device_id: int) -> bool:
	return has_device(device_id) and Input.is_action_just_pressed("interact_%s" % suffix(device_id))

func is_join_just_pressed(device_id: int) -> bool:
	return has_device(device_id) and Input.is_action_just_pressed("join_%s" % suffix(device_id))

func is_joined(device_id: int) -> bool:
	return _players.has(device_id)

func join(device_id: int) -> Dictionary:
	if _players.has(device_id):
		return _players[device_id]
	if _players.size() >= MAX_PLAYERS:
		return {}
	var number := _lowest_free_number()
	var player := {"device_id": device_id, "number": number, "color": ACCENT_COLORS[number -1], "is_bot": false}
	_players[device_id] = player
	return player

func players() -> Array:
	var out := _players.values()
	out.sort_custom(func(a,b): return a.number < b.number)
	return out

func join_all_connected() -> Array:
	for device_id in connected_devices():
		join(device_id)
	return players()

# A bot is a player whose pad is pressed by code. Its actions exist in the
# Input Map with no events bound, so has_device() and move_vector() treat it
# exactly like a human - the "six statues" trap from Watch 10 doesn't apply.
func add_bot() -> Dictionary:
	if _players.size() >= MAX_PLAYERS:
		return {}
	var device_id := BOT_DEVICE_BASE
	while _players.has(device_id):
		device_id += 1
	for action in BOT_ACTIONS:
		var per_device := "%s_pad%d" % [action, device_id]
		if not InputMap.has_action(per_device):
			InputMap.add_action(per_device, 0.0)
	var player := join(device_id)
	player.is_bot = true
	return player

func fill_with_bots() -> Array:
	while _players.size() < MAX_PLAYERS:
		add_bot()
	return players()

func humans() -> Array:
	return players().filter(func(p): return not p.is_bot)

func reset() -> void:
	_players.clear()

func _lowest_free_number() -> int:
	var taken := {}
	for p in _players.values():
		taken[p.number] = true
	for n in range(1, MAX_PLAYERS + 1):
		if not taken.has(n):
			return n
	return -1
