extends GutTest
## Validates every content file in data/ against docs/09-data-formats.md, so
## hand- or AI-written content can't break the simulation silently.

const DATA_DIR := "res://data/"
const PHASES: Array[String] = ["telegraph", "windup", "active", "recovery"]
const RANGES: Array[String] = ["long", "mid", "pocket", "clinch"]
const ALLOWS: Array[String] = [
	"elbows", "head_strikes_on_ground", "knees_to_head_standing",
	"knees_to_head_grounded", "heel_hooks", "slams", "takedowns",
]

## schema → folder, required fields and their JSON types.
const SCHEMAS := {
	"enum@1": { "folder": "enums", "fields": { "values": TYPE_DICTIONARY } },
	"action@1": { "folder": "actions", "fields": {
		"name": TYPE_STRING, "category": TYPE_STRING, "positions": TYPE_ARRAY, "ranges": TYPE_ARRAY,
		"phases_ms": TYPE_DICTIONARY, "stamina_cost": TYPE_FLOAT, "flags_self": TYPE_ARRAY,
		"stats": TYPE_DICTIONARY, "opportunities": TYPE_ARRAY,
	} },
	"position@1": { "folder": "positions", "fields": {
		"name": TYPE_STRING, "phase": TYPE_STRING, "roles": TYPE_ARRAY,
		"stamina_drain_per_s": TYPE_DICTIONARY, "control_score": TYPE_DICTIONARY,
		"strike_damage_multiplier": TYPE_DICTIONARY,
	} },
	"call@1": { "folder": "calls", "fields": {
		"name": TYPE_STRING, "kind": TYPE_STRING, "tier": TYPE_STRING, "voice_cost": TYPE_FLOAT,
		"positions": TYPE_ARRAY, "actions": TYPE_ARRAY,
	} },
	"trigger@1": { "folder": "triggers", "fields": {
		"name": TYPE_STRING, "type": TYPE_STRING, "match": TYPE_DICTIONARY,
	} },
	"rule@1": { "folder": "rules", "fields": {
		"name": TYPE_STRING, "trigger": TYPE_STRING, "action": TYPE_STRING,
		"priority": TYPE_FLOAT, "cooldown_ms": TYPE_FLOAT,
	} },
	"ruleset@1": { "folder": "rulesets", "fields": {
		"name": TYPE_STRING, "rounds": TYPE_FLOAT, "title_rounds": TYPE_FLOAT, "round_seconds": TYPE_FLOAT,
		"glove_oz": TYPE_FLOAT, "gear": TYPE_ARRAY, "allows": TYPE_DICTIONARY,
		"damage_multiplier": TYPE_FLOAT, "cut_multiplier": TYPE_FLOAT, "early_stoppage_bias": TYPE_FLOAT,
		"weigh_in": TYPE_STRING, "paid": TYPE_BOOL,
	} },
}

var _files: Dictionary = {}  # res:// path → parsed Dictionary (or null if unparseable)
var _by_folder: Dictionary = {}  # folder → { id → Dictionary }


func before_all() -> void:
	for path in _find_json(DATA_DIR):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_files[path] = parsed if parsed is Dictionary else null
		if parsed is Dictionary:
			var folder: String = path.get_base_dir().get_file()
			if not _by_folder.has(folder):
				_by_folder[folder] = {}
			_by_folder[folder][path.get_file().get_basename()] = parsed


func test_every_data_file_is_valid_json_with_a_known_schema() -> void:
	var problems: Array[String] = []
	assert_gt(_files.size(), 0, "expected content files in data/")
	for path: String in _files:
		var data: Variant = _files[path]
		if data == null:
			problems.append("%s is not a valid JSON object" % path)
		elif not SCHEMAS.has(data.get("schema")):
			problems.append("%s has unknown schema '%s'" % [path, data.get("schema")])
	_report(problems)


func test_every_id_matches_its_file_name_and_folder() -> void:
	var problems: Array[String] = []
	for path: String in _known_files():
		var data: Dictionary = _files[path]
		if data.get("id") != path.get_file().get_basename():
			problems.append("%s: id '%s' should match the file name" % [path, data.get("id")])
		var folder: String = SCHEMAS[data.schema].folder
		if path.get_base_dir().get_file() != folder:
			problems.append("%s: a %s file belongs in data/%s/" % [path, data.schema, folder])
	_report(problems)


func test_required_fields_are_present_with_the_right_types() -> void:
	var problems: Array[String] = []
	for path: String in _known_files():
		var data: Dictionary = _files[path]
		var fields: Dictionary = SCHEMAS[data.schema].fields
		for field: String in fields:
			if not data.has(field):
				problems.append("%s: missing '%s'" % [path, field])
			elif typeof(data[field]) != fields[field]:
				problems.append("%s: '%s' has the wrong type" % [path, field])
	_report(problems)


func test_action_timings_are_whole_ticks() -> void:
	var problems: Array[String] = []
	for id: String in _items("actions"):
		var phases: Dictionary = _items("actions")[id].get("phases_ms", {})
		for phase in PHASES:
			var ms: float = phases.get(phase, -1.0)
			if ms < 0 or fmod(ms, FightClock.TICK_MS) != 0:
				problems.append("action '%s': %s must be a multiple of %d ms (got %s)" % [id, phase, FightClock.TICK_MS, ms])
	_report(problems)


func test_values_come_from_the_allowed_lists() -> void:
	var problems: Array[String] = []
	_expect_in(problems, "action", "category", ["strike", "takedown", "defense", "movement", "clinch", "ground", "submission"])
	_expect_in(problems, "call", "kind", ["now", "read"])
	_expect_in(problems, "call", "tier", ["intent", "technique"])
	_expect_in(problems, "trigger", "type", ["event", "state", "threshold"])
	_expect_in(problems, "position", "phase", ["standing", "clinch", "ground"])
	_expect_in(problems, "ruleset", "weigh_in", ["same_day", "day_before"])
	for id: String in _items("actions"):
		var action: Dictionary = _items("actions")[id]
		for r: String in action.get("ranges", []):
			if r not in RANGES:
				problems.append("action '%s': unknown range '%s'" % [id, r])
		for f: Dictionary in action.get("flags_self", []):
			if f.get("from") not in PHASES or f.get("to") not in PHASES:
				problems.append("action '%s': flag phases must be one of %s" % [id, PHASES])
	for id: String in _items("rulesets"):
		var allows: Dictionary = _items("rulesets")[id].get("allows", {})
		var keys: Array = allows.keys()
		keys.sort()
		var expected: Array = ALLOWS.duplicate()
		expected.sort()
		if keys != expected:
			problems.append("ruleset '%s': 'allows' must list exactly %s" % [id, ALLOWS])
	_report(problems)


func test_references_point_to_things_that_exist() -> void:
	var problems: Array[String] = []
	var flags: Dictionary = _items("enums").get("flags", {}).get("values", {})
	var stats: Dictionary = _items("enums").get("stats", {}).get("values", {})
	for id: String in _items("actions"):
		var a: Dictionary = _items("actions")[id]
		var where := "action '%s'" % id
		_expect_ids(problems, where, "positions", a.get("positions", []))
		for f: Dictionary in a.get("flags_self", []):
			_expect_key(problems, where, "flag", f.get("flag"), flags)
		for o: Dictionary in a.get("opportunities", []):
			_expect_key(problems, where, "flag", o.get("opponent_flag"), flags)
		for side: String in a.get("stats", {}):
			for s: String in a.stats[side]:
				_expect_key(problems, where, "stat", s, stats)
		if a.has("takedown"):
			_expect_ids(problems, where, "positions", [a.takedown.on_success.position])
	for id: String in _items("calls"):
		var c: Dictionary = _items("calls")[id]
		var where := "call '%s'" % id
		_expect_ids(problems, where, "actions", c.get("actions", []))
		_expect_ids(problems, where, "positions", c.get("positions", []))
		if c.get("parent") != null:
			_expect_ids(problems, where, "calls", [c.parent])
		if c.get("kind") == "read":
			if not c.has("read"):
				problems.append("%s: read calls need a 'read' block" % where)
			else:
				_expect_ids(problems, where, "triggers", [c.read.get("trigger")])
	for id: String in _items("triggers"):
		_expect_ids(problems, "trigger '%s'" % id, "actions", _items("triggers")[id].get("match", {}).get("action_ids", []))
	for id: String in _items("rules"):
		var r: Dictionary = _items("rules")[id]
		_expect_ids(problems, "rule '%s'" % id, "triggers", [r.get("trigger")])
		_expect_ids(problems, "rule '%s'" % id, "actions", [r.get("action")])
	_report(problems)


# --- helpers -----------------------------------------------------------------

func _known_files() -> Array:
	return _files.keys().filter(func(p: String) -> bool:
		return _files[p] != null and SCHEMAS.has(_files[p].get("schema")))


func _items(folder: String) -> Dictionary:
	return _by_folder.get(folder, {})


func _expect_in(problems: Array[String], type: String, field: String, allowed: Array) -> void:
	var folder: String = SCHEMAS[type + "@1"].folder
	for id: String in _items(folder):
		var value: Variant = _items(folder)[id].get(field)
		if value not in allowed:
			problems.append("%s '%s': %s '%s' is not one of %s" % [type, id, field, value, allowed])


func _expect_ids(problems: Array[String], where: String, folder: String, ids: Array) -> void:
	for ref: Variant in ids:
		if not _items(folder).has(ref):
			problems.append("%s refers to missing %s '%s'" % [where, folder, ref])


func _expect_key(problems: Array[String], where: String, kind: String, key: Variant, known: Dictionary) -> void:
	if not known.has(key):
		problems.append("%s uses unknown %s '%s'" % [where, kind, key])


func _report(problems: Array[String]) -> void:
	if problems.is_empty():
		pass_test("no problems")
	else:
		fail_test("\n".join(problems))


func _find_json(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".json"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_find_json(dir_path.path_join(sub)))
	return found
