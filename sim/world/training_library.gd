class_name TrainingLibrary
extends RefCounted
## Training sessions and week plans loaded from data/sessions/*.json and
## data/week_plans/*.json (docs/09 session@1 and week_plan@1, docs/02 §3.5, D125).
## TrainingCamp runs them. Validated by tests/data/test_data_files.gd.

const SESSIONS_DIR := "res://data/sessions/"
const PLANS_DIR := "res://data/week_plans/"
## What kind of training a session is (docs/09 session@1 `kind`, D170): the planner colours its tiles by it.
const KINDS: Array[String] = ["striking", "wrestling", "grappling", "sparring", "conditioning", "mind", "recovery"]

static var _default: TrainingLibrary

var _sessions: Dictionary = {}  # id → session Dictionary
var _plans: Dictionary = {}  # id → week plan Dictionary


static func load_dirs(sessions_dir: String = SESSIONS_DIR, plans_dir: String = PLANS_DIR) -> TrainingLibrary:
	var library := TrainingLibrary.new()
	for session: Dictionary in _read_dir(sessions_dir):
		library.add_session(session)
	for plan: Dictionary in _read_dir(plans_dir):
		library.add_plan(plan)
	return library


## The data/ library, loaded once and shared (sessions and plans don't change mid-run).
static func shared() -> TrainingLibrary:
	if _default == null:
		_default = load_dirs()
	return _default


func add_session(session: Dictionary) -> void:
	_sessions[session.id] = session


func add_plan(plan: Dictionary) -> void:
	_plans[plan.id] = plan


func has_session(id: String) -> bool:
	return _sessions.has(id)


func has_plan(id: String) -> bool:
	return _plans.has(id)


func session(id: String) -> Dictionary:
	assert(_sessions.has(id), "no session '%s' in data/sessions" % id)
	return _sessions[id]


func plan(id: String) -> Dictionary:
	assert(_plans.has(id), "no week plan '%s' in data/week_plans" % id)
	return _plans[id]


func session_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_sessions.keys())
	out.sort()
	return out


func plan_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_plans.keys())
	out.sort()
	return out


static func _read_dir(dir_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				out.append(parsed)
	return out
