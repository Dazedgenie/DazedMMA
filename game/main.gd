extends Node3D
## Placeholder main scene: isometric orthographic camera over an empty arena.
## Replaced by the grey-box fight view in issue #19.


## Smallest window the UI still fits in (the game opens windowed and resizable).
const MIN_WINDOW_SIZE := Vector2i(960, 540)


func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE
	$UI/Version.text = "%s · prototype skeleton · Godot %s" % [
		ProjectSettings.get_setting("application/config/name"),
		Engine.get_version_info().string,
	]
