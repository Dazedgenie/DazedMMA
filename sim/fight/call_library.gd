class_name CallLibrary
extends RefCounted
## Coach calls loaded from data/calls/*.json (docs/09 call@2, docs/01 §6.4, §22):
## the nine intent calls and the read call "Catch the kick!". LiveCalls processes them.
##
## Three shapes of call (LiveCalls.shape):
##   - an attempt: a now call with `actions` (Takedown, Clinch, Get up): one try at one of them
##   - a focus: a now call with a `focus` block (Pressure, Circle out …): fight this way for a while
##   - a read: `kind: "read"` (Catch the kick): primed for a while, reacts to a trigger

const DEFAULT_DIR := "res://data/calls/"

static var _default: CallLibrary

var _calls: Dictionary = {}  # id → call Dictionary


static func load_dir(dir_path: String = DEFAULT_DIR) -> CallLibrary:
	var library := CallLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


## The data/calls library, loaded once and shared (calls don't change mid-run).
static func shared() -> CallLibrary:
	if _default == null:
		_default = load_dir()
	return _default


func add(call: Dictionary) -> void:
	_calls[call.id] = call


func has(id: String) -> bool:
	return _calls.has(id)


func get_call(id: String) -> Dictionary:
	return _calls[id]


## Every call id, in hotkey order (1–9, then 0, then letter keys like R, then calls with no hotkey by id).
func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_calls.keys())
	out.sort_custom(func(a: String, b: String) -> bool: return _order(a) < _order(b) or (_order(a) == _order(b) and a < b))
	return out


func _order(id: String) -> int:
	var key: Variant = _calls[id].get("hotkey")
	if key == null:
		return 100
	if key is String:
		return 50  # A letter key (Cut the cage! on R, D230; Hand fight! on H, D265), then by id.
	return 10 if int(key) == 0 else int(key)


## A call made from one action (tests and the debug console call moves straight from
## data/actions): an attempt at that move, costing no voice, with no technique check.
static func bare(action: Dictionary) -> Dictionary:
	return { "id": action.id, "name": action.name, "kind": "now", "voice_cost": 0, "positions": [],
		"actions": [action.id], "bare": true }
