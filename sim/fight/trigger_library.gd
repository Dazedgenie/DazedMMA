class_name TriggerLibrary
extends RefCounted
## Trigger definitions loaded from data/triggers/*.json (docs/09 trigger@1): the
## "when this happens" half of tells (#14), read calls (#16) and drilled rules
## (#17). An event trigger matches one FightEvent as one fighter sees it, so
## `actor: "self"` is the fighter whose tell, call or rule it is and
## `actor: "opponent"` is the other one.
##
## Match fields (all optional, all must hold): `actor`, `action_ids` (the event's
## action is one of these), `phase` (action_phase events), `defended` (strike_missed
## events: true = the opponent defended it, checks and slips included, not "out of range" or "opponent down").

const DEFAULT_DIR := "res://data/triggers/"
const SELF := "self"
const OPPONENT := "opponent"
const EVENT := "event"

static var _default: TriggerLibrary

var _triggers: Dictionary = {}  # id → trigger Dictionary


static func load_dir(dir_path: String = DEFAULT_DIR) -> TriggerLibrary:
	var library := TriggerLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()  # Same order on every platform.
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				library.add(parsed)
	return library


## The data/triggers library, loaded once and shared (triggers don't change mid-run).
static func shared() -> TriggerLibrary:
	if _default == null:
		_default = load_dir()
	return _default


func add(trigger: Dictionary) -> void:
	_triggers[trigger.id] = trigger


func has(id: String) -> bool:
	return _triggers.has(id)


func get_trigger(id: String) -> Dictionary:
	return _triggers[id]


## True when `event` sets off trigger `id` for fighter `viewer` (0 or 1).
func matches(id: String, event: FightEvent, viewer: int) -> bool:
	var t: Dictionary = _triggers[id]
	if t.type != EVENT or event.type != t.event:
		return false
	var m: Dictionary = t.match
	match m.get("actor", ""):
		SELF:
			if event.actor != viewer:
				return false
		OPPONENT:
			if event.actor != 1 - viewer:
				return false
	if m.has("action_ids") and not m.action_ids.has(event.data.get("action_id", "")):
		return false
	if m.has("phase") and event.data.get("phase", "") != m.phase:
		return false
	if m.has("defended") and bool(m.defended) != (String(event.data.get("reason", "defended")) == "defended"):
		return false  # Checked or slipped (D180) is defended too.
	return true


## The action a fighter's own move sets off: for a trigger on the fighter's own
## action starting ("self", one action, telegraph), that action id, else "".
## Tells use it for set-ups: the Wrestler's stance shift before the shot.
func own_start_action(id: String) -> String:
	var t: Dictionary = _triggers[id]
	var m: Dictionary = t.match
	if t.type != EVENT or t.event != FightEvent.ACTION_PHASE or m.get("actor", "") != SELF:
		return ""
	if m.get("phase", "") != "telegraph" or m.get("action_ids", []).size() != 1:
		return ""
	return m.action_ids[0]
