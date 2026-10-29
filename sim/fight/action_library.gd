class_name ActionLibrary
extends RefCounted
## Action definitions loaded from data/actions/*.json (docs/09-data-formats.md, action@2).
## The data files are validated by tests/data/test_data_files.gd.

const DEFAULT_DIR := "res://data/actions/"
const PHASES: Array[String] = ["telegraph", "windup", "active", "recovery"]

var _actions: Dictionary = {}  # id → action Dictionary
## Moves every fighter knows whatever their techniques (`basic: true`: get up, sprawl, clinch entry and break, #15).
var _basic: Array[String] = []


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
	if action.get("basic", false) and not _basic.has(action.id):
		_basic.append(action.id)
		_basic.sort()  # Same order whatever order the files loaded in.


## The moves every fighter knows (`basic: true`), sorted by id.
func basic_ids() -> Array[String]:
	return _basic


## True for a throw or a trip (D128, docs/01 §26): a takedown a sprawl can't stop.
static func is_throw(action: Dictionary) -> bool:
	return action.category == "takedown" and bool(action.takedown.get("throw", false))


## True for a leg lock (D132, docs/01 §30): the ankle lock, kneebar and heel hook.
static func is_leg_lock(action: Dictionary) -> bool:
	return action.category == "submission" and bool(action.submission.get("leg_lock", false))


## True when a fighter in `role` may use this action (the action's `roles`; none listed = anyone).
static func allows_role(action: Dictionary, role: String) -> bool:
	return not action.has("roles") or action.roles.has(role)


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
