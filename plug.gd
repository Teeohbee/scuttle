extends "res://addons/gd-plug/plug.gd"
# Addons this project depends on. Install with: godot --headless -s plug.gd install

func _plugging() -> void:
	plug("godot-gdunit-labs/gdUnit4", {"tag": "v6.2.2", "dev": true, "exclude": ["addons/gdUnit4/test"]})
