extends Node3D
## Placeholder main scene: isometric orthographic camera over an empty arena.
## Replaced by the grey-box fight view in issue #19.


func _ready() -> void:
	$UI/Version.text = "%s · prototype skeleton · Godot %s" % [
		ProjectSettings.get_setting("application/config/name"),
		Engine.get_version_info().string,
	]
