class_name PositionLibrary
extends RefCounted
## Position definitions loaded from data/positions/*.json (docs/09-data-formats.md,
## position@2), including how the fight moves between them: each position lists
## its transitions (action + the actor's role → the next position and both roles),
## so new positions are content, not code (docs/01 §4, issue #34).

const DEFAULT_DIR := "res://data/positions/"
const STANDING := "standing"
const NEUTRAL := "neutral"
const PHASE_STANDING := "standing"
const PHASE_GROUND := "ground"
const CLINCH := "clinch"
const SCRAMBLE := "scramble"
## A submission hold being fought for (D126): one fighter attacking it, the other defending.
const SUBMISSION := "submission"
const ATTACKER := "attacker"
const DEFENDER := "defender"
const TOP := "top"
const BOTTOM := "bottom"
## A transition's `result`: the move worked, half worked, or failed in a way that still moves
## the fight (a guillotine that doesn't lock pulls the attacker onto their back, D126).
const SUCCESS := "success"
const PARTIAL := "partial"
const FAILED := "failed"

static var _default: PositionLibrary

var _positions: Dictionary = {}  # id → position Dictionary


static func load_dir(dir_path: String = DEFAULT_DIR) -> PositionLibrary:
	var library := PositionLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


## The data/positions library, loaded once and shared (positions don't change mid-run).
static func shared() -> PositionLibrary:
	if _default == null:
		_default = load_dir()
	return _default


func add(position: Dictionary) -> void:
	_positions[position.id] = position


func has(id: String) -> bool:
	return _positions.has(id)


func get_position(id: String) -> Dictionary:
	return _positions[id]


## Where `action_id` takes the fight when the fighter in `role` lands it from
## `from_id`: {action, from_role, to, roles: {actor, opponent}}, or {} when it
## doesn't move the fight anywhere. `result` is "success", or "partial" for a move
## that half worked (a shot that ends in a scramble, #15); entries without a
## `result` are for success.
func transition(from_id: String, role: String, action_id: String, result: String = SUCCESS) -> Dictionary:
	for t: Dictionary in _positions[from_id].get("transitions", []):
		if t.action == action_id and t.from_role == role and t.get("result", SUCCESS) == result:
			return t
	return {}
