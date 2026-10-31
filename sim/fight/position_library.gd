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
## Moves that take the fight somewhere when they work (D130): they're only possible where the
## position data says where they go for that role. Tie-ups (`ties_up_ms`) keep the fight put.
const MOVING_CATEGORIES := { "takedown": true, "clinch": true, "ground": true, "submission": true }
## How the feed names whoever is in the top role, unless the position says otherwise (`top_label`).
const TOP_LABEL := "on top"
const PARTIAL := "partial"
const FAILED := "failed"
## A shot at a man with his back on the fence that doesn't put him down presses him there
## instead (D220): the shooter stays on him, tied up against the fence.
const PRESSED := "pressed"

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


## True when a fighter in `role` has somewhere to take the fight with this move from position
## `id` (D130): a move that moves the fight needs a transition for that role here, so one move
## can work from different roles in different positions (the armbar: the bottom of full guard
## and the top of mount). Strikes, defenses, tie-ups and the cage clinch's drive and spin-off (D220)
## don't move the fight, so they always do.
func leads_somewhere(id: String, role: String, action: Dictionary) -> bool:
	var block: Dictionary = action.get(action.category, {})
	if not MOVING_CATEGORIES.has(action.category) or block.has("ties_up_ms") or block.has("drives_m") or block.get("turns", false) \
			or block.has("grip"):
		return true
	return not transition(id, role, action.id).is_empty()


## How the feed and the screen say who's in the top role here: "on top", or "has the back".
func top_label(id: String) -> String:
	return String(_positions[id].get("top_label", TOP_LABEL)) if _positions.has(id) else TOP_LABEL


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
