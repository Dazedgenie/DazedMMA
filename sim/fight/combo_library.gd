class_name ComboLibrary
extends RefCounted
## Combinations loaded from data/combos/*.json (docs/09 combo@1, D133, docs/01 §31): a
## named run of strikes a fighter has drilled (the 1-2, a jab into a low kick). A fighter
## throws the ones in their profile's `combos`. Validated by tests/data/test_data_files.gd.

const DEFAULT_DIR := "res://data/combos/"

static var _default: ComboLibrary

var _combos: Dictionary = {}  # id → combo Dictionary


static func load_dir(dir_path: String = DEFAULT_DIR) -> ComboLibrary:
	var library := ComboLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


## The data/combos library, loaded once and shared (combinations don't change mid-run).
static func shared() -> ComboLibrary:
	if _default == null:
		_default = load_dir()
	return _default


func add(combo: Dictionary) -> void:
	_combos[combo.id] = combo


func has(id: String) -> bool:
	return _combos.has(id)


func get_combo(id: String) -> Dictionary:
	return _combos[id]


func ids() -> Array:
	return _combos.keys()


## The move at `step` of this combination (0 is the first), or "" past its end.
func move(id: String, step: int) -> String:
	var moves: Array = _combos[id].moves
	return String(moves[step]) if step >= 0 and step < moves.size() else ""


## How many moves this combination has.
func length(id: String) -> int:
	return (_combos[id].moves as Array).size()
