class_name RuleLibrary
extends RefCounted
## Drilled-rule presets loaded from data/rules/*.json (docs/09 rule@2, docs/01 §6.0, §23):
## "when this happens (a trigger) → do that (a move)", with a cooldown. DrilledRules runs them.

const DEFAULT_DIR := "res://data/rules/"

static var _default: RuleLibrary

var _rules: Dictionary = {}  # id → rule Dictionary


static func load_dir(dir_path: String = DEFAULT_DIR) -> RuleLibrary:
	var library := RuleLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


## The data/rules library, loaded once and shared (rules don't change mid-run).
static func shared() -> RuleLibrary:
	if _default == null:
		_default = load_dir()
	return _default


func add(rule: Dictionary) -> void:
	_rules[rule.id] = rule


func has(id: String) -> bool:
	return _rules.has(id)


func get_rule(id: String) -> Dictionary:
	return _rules[id]


func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_rules.keys())
	out.sort()
	return out
