class_name FighterLibrary
extends RefCounted
## Fighter profiles loaded from data/fighters/*.json (docs/09 fighter@1, D94).
## One format for authored fighters and generated ones: a profile may name a
## `template` fighter, and anything it leaves out comes from there (stats, style,
## personality and tendencies merge key by key). Validated by tests/data/test_data_files.gd.

const DEFAULT_DIR := "res://data/fighters/"
## Fields that merge key by key over the template instead of replacing it.
const MERGED_FIELDS: Array[String] = ["frame", "stats", "personality", "style", "tendencies"]

var _profiles: Dictionary = {}  # id → profile Dictionary as written


static func load_dir(dir_path: String = DEFAULT_DIR) -> FighterLibrary:
	var library := FighterLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


func add(profile: Dictionary) -> void:
	_profiles[profile.id] = profile


func has(id: String) -> bool:
	return _profiles.has(id)


func ids() -> Array:
	return _profiles.keys()


## The profile with its template filled in.
func profile(id: String) -> Dictionary:
	var own: Dictionary = _profiles[id]
	var template_id: Variant = own.get("template")
	if template_id == null:
		return own.duplicate(true)
	var out: Dictionary = profile(template_id)
	for field: String in own:
		if field in MERGED_FIELDS and out.get(field) is Dictionary and own[field] is Dictionary:
			out[field].merge(own[field], true)
		else:
			out[field] = own[field]
	out.template = template_id
	return out


## A fresh FighterState for a fight. Make new ones for every fight (a fight changes them).
func make(id: String) -> FighterState:
	return FighterState.from_profile(profile(id))


func make_pair(red_id: String, blue_id: String) -> Array[FighterState]:
	return [make(red_id), make(blue_id)]
