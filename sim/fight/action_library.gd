class_name ActionLibrary
extends RefCounted
## Action definitions loaded from data/actions/*.json (docs/09-data-formats.md, action@2).
## The data files are validated by tests/data/test_data_files.gd.

const DEFAULT_DIR := "res://data/actions/"
const PHASES: Array[String] = ["telegraph", "windup", "active", "recovery"]

var _actions: Dictionary = {}  # id → action Dictionary


static func load_dir(dir_path: String = DEFAULT_DIR) -> ActionLibrary:
	var library := ActionLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


func add(action: Dictionary) -> void:
	_actions[action.id] = action


func has(id: String) -> bool:
	return _actions.has(id)


func get_action(id: String) -> Dictionary:
	return _actions[id]


func ids() -> Array:
	return _actions.keys()


## Length of one phase in ticks (data is in ms of fight time, whole ticks only).
func phase_ticks(id: String, phase: String) -> int:
	return int(_actions[id].phases_ms[phase]) / FightClock.TICK_MS


func total_ticks(id: String) -> int:
	var total: int = 0
	for phase in PHASES:
		total += phase_ticks(id, phase)
	return total
