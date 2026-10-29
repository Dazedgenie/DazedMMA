extends GutTest
## Validates every content file in data/ against docs/09-data-formats.md, so
## hand- or AI-written content can't break the simulation silently.

const DATA_DIR := "res://data/"
const PHASES: Array[String] = ["telegraph", "windup", "active", "recovery"]
const RANGES: Array[String] = ["long", "mid", "pocket", "clinch"]
const STANCES: Array[String] = ["orthodox", "southpaw", "switch"]
const BUILDS: Array[String] = ["lean", "average", "stocky"]
const PERSONALITY_AXES: Array[String] = ["ego", "discipline", "coachable", "loyal"]
## fighter@1 fields that a template may fill in, and their JSON types (docs/09).
const FIGHTER_FIELDS := {
	"frame": TYPE_DICTIONARY, "stance": TYPE_STRING, "stats": TYPE_DICTIONARY, "personality": TYPE_DICTIONARY,
	"style": TYPE_DICTIONARY, "gifts": TYPE_ARRAY, "flaws": TYPE_ARRAY, "techniques": TYPE_ARRAY,
	"tendencies": TYPE_DICTIONARY, "tells": TYPE_ARRAY,
}
## What an event trigger may match on (docs/09 trigger@1, TriggerLibrary).
const TRIGGER_MATCH_KEYS: Array[String] = ["actor", "action_ids", "phase", "defended"]
const TRIGGER_EVENTS: Array[String] = [
	FightEvent.ACTION_PHASE, FightEvent.ACTION_ENDED, FightEvent.STRIKE_LANDED, FightEvent.STRIKE_MISSED,
	FightEvent.ROCKED, FightEvent.KNOCKDOWN, FightEvent.GOT_UP, FightEvent.RECOVERED,
	FightEvent.RANGE_CHANGED, FightEvent.CAGE_CHANGED, FightEvent.POSITION_CHANGED,
]
const LEANINGS: Array[String] = ["pace", "range", "base", "risk"]
const CATEGORIES: Array[String] = ["strike", "takedown", "defense", "movement", "clinch", "ground", "submission", "feint"]
const ROLES: Array[String] = ["neutral", "top", "bottom", "attacker", "defender"]
## What a focus call (docs/09 call@2) may hold.
const FOCUS_KEYS: Array[String] = ["duration_ms", "leanings", "weights", "read_bonus", "sprawl_bonus", "struggle", "struggle_stamina"]
## Where a submission (docs/09 action@2 `submission.escape_to`, D126) leaves the fight when the defender gets out.
const ESCAPES: Array[String] = ["back", "scramble"]
## The minigames a session can be played as (D38, docs/02 §3.2).
const MINIGAMES: Array[String] = [
	"mitt_work", "heavy_bag", "thai_pads", "wrestling_chain", "sprawl_reflex",
	"rolling_puzzle", "roadwork", "film_study", "hard_sparring", "meditation",
]
const ALLOWS: Array[String] = [
	"elbows", "head_strikes_on_ground", "knees_to_head_standing",
	"knees_to_head_grounded", "heel_hooks", "slams", "takedowns", "soccer_kicks", "stomps",
]

## schema → folder, required fields and their JSON types.
const SCHEMAS := {
	"enum@1": { "folder": "enums", "fields": { "values": TYPE_DICTIONARY } },
	"action@2": { "folder": "actions", "fields": {
		"name": TYPE_STRING, "category": TYPE_STRING, "positions": TYPE_ARRAY, "ranges": TYPE_ARRAY,
		"phases_ms": TYPE_DICTIONARY, "stamina_cost": TYPE_FLOAT, "flags_self": TYPE_ARRAY,
		"stats": TYPE_DICTIONARY, "opportunities": TYPE_ARRAY,
	} },
	"position@2": { "folder": "positions", "fields": {
		"name": TYPE_STRING, "phase": TYPE_STRING, "roles": TYPE_ARRAY,
		"stamina_drain_per_s": TYPE_DICTIONARY, "control_score": TYPE_DICTIONARY,
		"strike_damage_multiplier": TYPE_DICTIONARY, "transitions": TYPE_ARRAY,
	} },
	"call@2": { "folder": "calls", "fields": {
		"name": TYPE_STRING, "kind": TYPE_STRING, "tier": TYPE_STRING, "voice_cost": TYPE_FLOAT,
		"positions": TYPE_ARRAY, "actions": TYPE_ARRAY,
	} },
	"gameplan@1": { "folder": "gameplans", "fields": {
		"name": TYPE_STRING, "leanings": TYPE_DICTIONARY, "weights": TYPE_DICTIONARY,
	} },
	"trigger@1": { "folder": "triggers", "fields": {
		"name": TYPE_STRING, "type": TYPE_STRING, "match": TYPE_DICTIONARY,
	} },
	"rule@2": { "folder": "rules", "fields": {
		"name": TYPE_STRING, "trigger": TYPE_STRING, "action": TYPE_STRING, "cooldown_ms": TYPE_FLOAT,
	} },
	"ruleset@1": { "folder": "rulesets", "fields": {
		"name": TYPE_STRING, "rounds": TYPE_FLOAT, "title_rounds": TYPE_FLOAT, "round_seconds": TYPE_FLOAT,
		"glove_oz": TYPE_FLOAT, "gear": TYPE_ARRAY, "allows": TYPE_DICTIONARY,
		"damage_multiplier": TYPE_FLOAT, "cut_multiplier": TYPE_FLOAT, "early_stoppage_bias": TYPE_FLOAT,
		"weigh_in": TYPE_STRING, "paid": TYPE_BOOL,
	} },
	"fighter@1": { "folder": "fighters", "fields": { "name": TYPE_STRING } },
	"playtest@1": { "folder": "playtest", "fields": {
		"name": TYPE_STRING, "order": TYPE_FLOAT, "red": TYPE_STRING, "blue": TYPE_STRING, "calls": TYPE_ARRAY,
		"rules": TYPE_ARRAY, "tell_cue": TYPE_BOOL, "tip": TYPE_STRING,
	} },
	"session@1": { "folder": "sessions", "fields": {
		"name": TYPE_STRING, "trains": TYPE_DICTIONARY, "xp": TYPE_FLOAT, "fatigue": TYPE_FLOAT,
		"injury_risk": TYPE_FLOAT, "leanings": TYPE_DICTIONARY, "chin_wear": TYPE_FLOAT,
	} },
	"week_plan@1": { "folder": "week_plans", "fields": { "name": TYPE_STRING, "about": TYPE_STRING, "days": TYPE_ARRAY } },
	"combo@1": { "folder": "combos", "fields": { "name": TYPE_STRING, "moves": TYPE_ARRAY } },
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
	_expect_in(problems, "action", "category", CATEGORIES)
	_expect_in(problems, "call", "kind", ["now", "read"])
	_expect_in(problems, "call", "tier", ["intent", "technique"])
	_expect_in(problems, "trigger", "type", ["event", "state", "threshold"])
	_expect_in(problems, "position", "phase", ["standing", "clinch", "ground"])
	for id: String in _items("positions"):
		var p: Dictionary = _items("positions")[id]
		if p.has("top_label") and (not p.top_label is String or not p.get("roles", []).has("top")):
			problems.append("position '%s': top_label is how the feed says who's on top (\"has the back\"), for a position with a top role (D130)" % id)
	_expect_in(problems, "ruleset", "weigh_in", ["same_day", "day_before"])
	for id: String in _items("rulesets"):
		var judging: Variant = _items("rulesets")[id].get("judging", Ruleset.ROUND_CARDS)
		if judging not in [Ruleset.ROUND_CARDS, Ruleset.WHOLE_FIGHT]:
			problems.append("ruleset '%s': judging is \"%s\" (round cards, left out) or \"%s\" (D141), not '%s'" % [id, Ruleset.ROUND_CARDS, Ruleset.WHOLE_FIGHT, judging])
	for id: String in _items("actions"):
		var action: Dictionary = _items("actions")[id]
		for r: String in action.get("ranges", []):
			if r not in RANGES:
				problems.append("action '%s': unknown range '%s'" % [id, r])
		for f: Dictionary in action.get("flags_self", []):
			if f.get("from") not in PHASES or f.get("to") not in PHASES:
				problems.append("action '%s': flag phases must be one of %s" % [id, PHASES])
		if action.get("strike") is Dictionary and action.strike.has("downed"):
			var needs_down: bool = action.opportunities.any(func(o: Dictionary) -> bool: return o.get("opponent_flag", "") == "DOWN" and o.get("required", false))
			if not action.strike.downed is bool or not needs_down or not action.positions == ["standing"]:
				problems.append("action '%s': a downed strike (strike.downed true, D141) is thrown standing and needs the DOWN opening (required)" % id)
		var push: Variant = action.get("strike", {}).get("push_m", 0.0) if action.get("strike") is Dictionary else 0.0
		if not (push is float) or push < 0.0:
			problems.append("action '%s': strike.push_m is metres pushed back, 0 or more" % id)
		var category: String = action.get("category", "")
		if category in ["takedown", "defense", "clinch", "ground", "submission"]:
			var block: Variant = action.get(category)
			if not block is Dictionary or not block.get("base_success") is float:
				problems.append("action '%s': a %s move needs a '%s' block with base_success" % [id, category, category])
			elif not block.get("partial_within", 0.0) is float or block.get("partial_within", 0.0) < 0.0:
				problems.append("action '%s': %s.partial_within is a chance, 0 or more" % [id, category])
			elif block.has("ties_up_ms") and ((category != "ground" and category != "clinch") or not block.ties_up_ms is float or block.ties_up_ms <= 0.0):
				problems.append("action '%s': ties_up_ms (how long a tie-up breaks the opponent's posture) is a ground or clinch move's, in ms (D121, D129)" % id)
			elif (block.has("throw") or block.has("landing_damage")) and (category != "takedown" or not block.get("throw", false) is bool \
					or not block.get("landing_damage", 0.0) is float or block.get("landing_damage", 0.0) < 0.0):
				problems.append("action '%s': throw (true or false) and landing_damage (0 or more) are a takedown's (D128)" % id)
			elif category == "submission" and (not block.get("start_danger") is float or block.start_danger <= 0.0 or block.start_danger >= 100.0 \
					or block.get("escape_to") not in ESCAPES):
				problems.append("action '%s': a submission needs start_danger (between 0 and 100) and escape_to (one of %s)" % [id, ESCAPES])
			elif block.has("ai_without_opening") and (category != "submission" or not _any_time_ok(block.ai_without_opening, action.get("positions", []))):
				problems.append("action '%s': ai_without_opening (true or false, or a list of the move's positions, D132) is a submission's (D130)" % id)
			elif (block.has("leg_lock") or block.has("step")) and (category != "submission" or not block.get("leg_lock", false) is bool \
					or not block.get("step", 20.0) is float or block.get("step", 20.0) <= 0.0 or block.get("step", 20.0) > 100.0):
				problems.append("action '%s': leg_lock (true or false) and step (danger a beat, above 0 up to 100) are a submission's (D132)" % id)
		if category == "feint":
			var feint: Variant = action.get("feint")
			if not feint is Dictionary or not feint.get("base_success") is float or not feint.get("bites_ms") is float \
					or feint.bites_ms <= 0.0 or fmod(feint.bites_ms, FightClock.TICK_MS) != 0:
				problems.append("action '%s': a feint needs a 'feint' block with base_success and bites_ms (how long the opponent bites, a multiple of %d ms, D131)" % [id, FightClock.TICK_MS])
		if action.has("basic") and not action.basic is bool:
			problems.append("action '%s': basic is true or false" % id)
		for r: Variant in action.get("roles", []):
			if r not in ROLES:
				problems.append("action '%s': unknown role '%s'" % [id, r])
	for id: String in _items("rulesets"):
		var allows: Dictionary = _items("rulesets")[id].get("allows", {})
		var keys: Array = allows.keys()
		keys.sort()
		var expected: Array = ALLOWS.duplicate()
		expected.sort()
		if keys != expected:
			problems.append("ruleset '%s': 'allows' must list exactly %s" % [id, ALLOWS])
		var lengths: Variant = _items("rulesets")[id].get("round_lengths", [])
		if not lengths is Array or (not lengths.is_empty() and lengths.size() != int(_items("rulesets")[id].get("rounds", 0))):
			problems.append("ruleset '%s': round_lengths is one length in seconds a round, or left out (D141)" % id)
		else:
			for n: Variant in lengths:
				if not n is float or n <= 0.0 or fmod(n, 1.0) != 0.0:
					problems.append("ruleset '%s': each of round_lengths is a whole number of seconds (D141)" % id)
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
			if o.has("own_flag") == o.has("opponent_flag"):
				problems.append("%s: each opportunity names one flag, opponent_flag or own_flag" % where)
			_expect_key(problems, where, "flag", o.get("own_flag", o.get("opponent_flag")), flags)
			if o.has("own_flag") and o.get("required", false):
				problems.append("%s: only an opponent_flag opportunity can be required" % where)
			if o.has("ai_takes") and (not o.ai_takes is bool or not o.get("required", false)):
				problems.append("%s: ai_takes (true or false) goes on a required opening (D128)" % where)
			if o.has("target") and o.target not in ["head", "body", "legs"]:
				problems.append("%s: an opportunity's target is head, body or legs" % where)
		for side: String in a.get("stats", {}):
			for s: String in a.stats[side]:
				_expect_key(problems, where, "stat", s, stats)
	for id: String in _items("calls"):
		var c: Dictionary = _items("calls")[id]
		var where := "call '%s'" % id
		_expect_ids(problems, where, "actions", c.get("actions", []))
		_expect_ids(problems, where, "positions", c.get("positions", []))
		if c.has("then"):
			if not c.then is Array or c.then.is_empty():
				problems.append("%s: then lists the moves that follow the first one" % where)
			else:
				_expect_ids(problems, where, "actions", c.then)
		if c.get("requires_technique") != null:
			_expect_ids(problems, where, "actions", [c.requires_technique])
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
	for id: String in _items("playtest"):
		var p: Dictionary = _items("playtest")[id]
		var where := "playtest step '%s'" % id
		_expect_ids(problems, where, "fighters", [p.get("red"), p.get("blue")])
		_expect_ids(problems, where, "calls", p.get("calls", []))
		var rules: Array = p.get("rules", [])
		if rules.size() > 2:
			problems.append("%s: there are two rule slots" % where)
		for entry: Variant in rules:
			if not entry is Array or entry.size() != 2 or not entry[1] is float or entry[1] < 0.0 or entry[1] > 100.0:
				problems.append("%s: each rule is [rule id, drilled 0–100]" % where)
			else:
				_expect_ids(problems, where, "rules", [entry[0]])
	_report(problems)


func test_calls_are_an_attempt_a_focus_or_a_read() -> void:
	var problems: Array[String] = []
	var hotkeys: Dictionary = {}
	for id: String in _items("calls"):
		var c: Dictionary = _items("calls")[id]
		var where := "call '%s'" % id
		var key: Variant = c.get("hotkey")
		if key != null:
			if not key is float or key < 0 or key > 9 or fmod(key, 1.0) != 0.0:
				problems.append("%s: hotkey is a digit 0–9 or null" % where)
			else:
				# Two calls can share a key when they're never possible in the same position
				# (1 is Pressure! standing and Ground and pound! on top, D121).
				for other: String in hotkeys.get(key, []):
					var theirs: Array = _items("calls")[other].get("positions", [])
					var mine: Array = c.get("positions", [])
					if mine.is_empty() or theirs.is_empty() or mine.any(func(p: Variant) -> bool: return theirs.has(p)):
						problems.append("%s: hotkey %d is taken by '%s' in the same position" % [where, key, other])
				if not hotkeys.has(key):
					hotkeys[key] = []
				hotkeys[key].append(id)
		for r: Variant in c.get("roles", []):
			if r not in ROLES:
				problems.append("%s: unknown role '%s'" % [where, r])
		if c.has("priority_boost"):
			problems.append("%s: priority_boost went with call@1; an accepted call claims the choice outright" % where)
		var actions: Array = c.get("actions", [])
		if c.get("kind") == "read":
			if actions.is_empty() or c.has("focus"):
				problems.append("%s: a read call names the actions it reacts with, and no focus" % where)
			if c.get("read") is Dictionary:
				_expect_ticks(problems, where, "read.duration_ms", c.read.get("duration_ms"))
				var cost: Variant = c.read.get("attention_cost", 0.0)
				if not cost is float or cost < 0.0 or cost > 0.5:
					problems.append("%s: read.attention_cost is a share of defense from 0 to 0.5" % where)
		elif actions.is_empty() == not c.has("focus"):
			problems.append("%s: a now call has either actions (an attempt) or a focus block, not both" % where)
		if c.has("then") and (c.get("kind") == "read" or actions.is_empty()):
			problems.append("%s: only an attempt has a then list" % where)
		if c.has("combo") and (not c.combo is bool or c.get("kind") != "read"):
			problems.append("%s: combo is true or false, on a read call (D133)" % where)
		if c.get("combo", false):
			for move: Variant in actions:
				if _items("actions").get(move, {}).get("category", "") != "strike":
					problems.append("%s: a combo call's actions are the single strikes it falls back on" % where)
		if c.has("focus"):
			var focus: Variant = c.focus
			if not focus is Dictionary:
				problems.append("%s: focus is an object" % where)
				continue
			for k: Variant in focus:
				if k not in FOCUS_KEYS:
					problems.append("%s: focus has unknown key '%s'" % [where, k])
			_expect_ticks(problems, where, "focus.duration_ms", focus.get("duration_ms"))
			_expect_numbers(problems, where, "focus.leanings", focus.get("leanings", {}), LEANINGS, -100, 100)
			_expect_weights(problems, where, "focus.weights", focus.get("weights", {}))
			_expect_numbers(problems, where, "focus.read_bonus", focus.get("read_bonus", {}), CATEGORIES, 0, 1)
			var sprawl: Variant = focus.get("sprawl_bonus", 0.0)
			if not sprawl is float or sprawl < 0.0 or sprawl > 1.0:
				problems.append("%s: focus.sprawl_bonus is a chance from 0 to 1" % where)
			var struggle: Variant = focus.get("struggle", 0.0)
			if not struggle is float or struggle < 0.0 or struggle > 0.5:
				problems.append("%s: focus.struggle is a push on a submission's beats, a chance from 0 to 0.5" % where)
			var struggle_stamina: Variant = focus.get("struggle_stamina", 0.0)
			if not struggle_stamina is float or struggle_stamina < 0.0:
				problems.append("%s: focus.struggle_stamina is stamina a beat, 0 or more" % where)
	for id: String in _items("gameplans"):
		var g: Dictionary = _items("gameplans")[id]
		_expect_numbers(problems, "gameplan '%s'" % id, "leanings", g.get("leanings", {}), LEANINGS, -100, 100)
		_expect_weights(problems, "gameplan '%s'" % id, "weights", g.get("weights", {}))
	_report(problems)


func test_event_triggers_say_what_they_match() -> void:
	var problems: Array[String] = []
	for id: String in _items("triggers"):
		var t: Dictionary = _items("triggers")[id]
		var where := "trigger '%s'" % id
		if t.get("type") != "event":
			continue  # State and threshold match fields come with #16.
		if t.get("event") not in TRIGGER_EVENTS:
			problems.append("%s: event '%s' is not one of %s" % [where, t.get("event"), TRIGGER_EVENTS])
		var m: Dictionary = t.get("match", {}) if t.get("match") is Dictionary else {}
		for key: String in m:
			if key not in TRIGGER_MATCH_KEYS:
				problems.append("%s: can't match on '%s' (only %s)" % [where, key, TRIGGER_MATCH_KEYS])
		if m.has("actor") and m.actor not in ["self", "opponent"]:
			problems.append("%s: actor is 'self' or 'opponent'" % where)
		if m.has("phase") and m.phase not in PHASES:
			problems.append("%s: phase must be one of %s" % [where, PHASES])
		if m.has("defended") and not m.defended is bool:
			problems.append("%s: defended is true or false" % where)
		if m.has("action_ids") and not m.action_ids is Array:
			problems.append("%s: action_ids is a list" % where)
	_report(problems)


func test_position_transitions_lead_somewhere_real() -> void:
	var problems: Array[String] = []
	var positions: Dictionary = _items("positions")
	for id: String in positions:
		var p: Dictionary = positions[id]
		var where := "position '%s'" % id
		var seen: Dictionary = {}
		for t: Variant in p.get("transitions", []):
			if not t is Dictionary or not t.get("roles") is Dictionary:
				problems.append("%s: each transition needs {action, from_role, to, roles: {actor, opponent}}" % where)
				continue
			_expect_ids(problems, where, "actions", [t.get("action")])
			_expect_ids(problems, where, "positions", [t.get("to")])
			if t.get("from_role") not in p.get("roles", []):
				problems.append("%s: transition '%s' starts from role '%s', not one of %s" % [where, t.get("action"), t.get("from_role"), p.get("roles", [])])
			if t.get("result", "success") not in ["success", "partial", "failed"]:
				problems.append("%s: transition '%s' has result '%s', not success, partial or failed" % [where, t.get("action"), t.get("result")])
			var key: String = "%s/%s/%s" % [t.get("action"), t.get("from_role"), t.get("result", "success")]
			if seen.has(key):
				problems.append("%s: '%s' from '%s' (%s) is listed twice" % [where, t.get("action"), t.get("from_role"), t.get("result", "success")])
			seen[key] = true
			var action: Dictionary = _items("actions").get(t.get("action"), {})
			if not action.is_empty() and id not in action.get("positions", []):
				problems.append("%s: transition '%s' uses an action that can't be done from here" % [where, t.get("action")])
			if not action.is_empty() and action.has("roles") and t.get("from_role") not in action.roles:
				problems.append("%s: transition '%s' starts from role '%s', which the action doesn't allow" % [where, t.get("action"), t.get("from_role")])
			var target: Dictionary = positions.get(t.get("to"), {})
			for side: String in ["actor", "opponent"]:
				if not target.is_empty() and t.roles.get(side) not in target.get("roles", []):
					problems.append("%s: transition '%s' gives the %s role '%s', not one of %s's roles" % [where, t.get("action"), side, t.roles.get(side), t.get("to")])
	_report(problems)


func test_fighter_profiles_are_complete_and_in_range() -> void:
	var problems: Array[String] = []
	var fighters: Dictionary = _items("fighters")
	var stats: Dictionary = _items("enums").get("stats", {}).get("values", {})
	var gifts: Dictionary = _items("enums").get("gifts", {}).get("values", {})
	var flaws: Dictionary = _items("enums").get("flaws", {}).get("values", {})
	for id: String in fighters:
		var f: Dictionary = fighters[id]
		var where := "fighter '%s'" % id
		var template: Variant = f.get("template")
		if template != null:
			if not fighters.has(template):
				problems.append("%s refers to missing fighters '%s'" % [where, template])
			elif fighters[template].get("template") != null:
				problems.append("%s: template '%s' has a template of its own (one level only)" % [where, template])
		for field: String in FIGHTER_FIELDS:
			if not f.has(field):
				if template == null:
					problems.append("%s: missing '%s' (only fighters with a template may leave it out)" % [where, field])
			elif typeof(f[field]) != FIGHTER_FIELDS[field]:
				problems.append("%s: '%s' has the wrong type" % [where, field])
		if f.get("stance", "orthodox") not in STANCES:
			problems.append("%s: stance '%s' is not one of %s" % [where, f.stance, STANCES])
		var frame: Dictionary = f.get("frame", {}) if f.get("frame") is Dictionary else {}
		if frame.has("build") and frame.build not in BUILDS:
			problems.append("%s: build '%s' is not one of %s" % [where, frame.build, BUILDS])
		_expect_numbers(problems, where, "stats", f.get("stats", {}), stats.keys(), 0, 100)
		_expect_numbers(problems, where, "style", f.get("style", {}), StyleLeanings.LEANINGS, -100, 100)
		_expect_numbers(problems, where, "personality", f.get("personality", {}), PERSONALITY_AXES, -100, 100)
		for g: Variant in f.get("gifts", []):
			_expect_key(problems, where, "gift", g, gifts)
		for fl: Variant in f.get("flaws", []):
			_expect_key(problems, where, "flaw", fl, flaws)
		_expect_ids(problems, where, "actions", f.get("techniques", []))
		var tendencies: Dictionary = f.get("tendencies", {}) if f.get("tendencies") is Dictionary else {}
		var work_rate: Variant = tendencies.get("work_rate", 0.0)
		if not (work_rate is float) or work_rate < 0.0 or work_rate > 1.0:
			problems.append("%s: tendencies.work_rate must be a chance from 0 to 1" % where)
		var weights: Variant = tendencies.get("actions", {})
		if not weights is Dictionary:
			problems.append("%s: tendencies.actions must map action ids to weights" % where)
		else:
			_expect_ids(problems, where, "actions", weights.keys())
			_expect_numbers(problems, where, "tendencies.actions", weights, weights.keys(), 0, 10)
		for field: String in ["age", "potential"]:
			if f.has(field) and not f[field] is float:
				problems.append("%s: '%s' is a number" % [where, field])
		if f.get("age", 25.0) is float and (f.get("age", 25.0) < 14.0 or f.get("age", 25.0) > 45.0 or fmod(f.get("age", 25.0), 1.0) != 0.0):
			problems.append("%s: age is whole years from 14 to 45" % where)
		if f.get("potential", 75.0) is float and (f.get("potential", 75.0) < 0.0 or f.get("potential", 75.0) > 100.0):
			problems.append("%s: potential is 0–100" % where)
		if f.has("combos"):
			if not f.combos is Array:
				problems.append("%s: 'combos' is a list of data/combos ids" % where)
			else:
				_expect_ids(problems, where, "combos", f.combos)
		for t: Variant in f.get("tells", []):
			if not t is Dictionary or not (t.get("chance") is float) or not (t.get("within_ms") is float):
				problems.append("%s: each tell needs {trigger, action, chance, within_ms}" % where)
				continue
			_expect_ids(problems, where, "triggers", [t.get("trigger")])
			_expect_ids(problems, where, "actions", [t.get("action")])
			if t.chance < 0.0 or t.chance > 1.0 or fmod(t.within_ms, FightClock.TICK_MS) != 0:
				problems.append("%s: a tell's chance is 0–1 and within_ms a multiple of %d" % [where, FightClock.TICK_MS])
	_report(problems)


func test_combinations_are_runs_of_standing_strikes_their_fighters_know() -> void:
	var problems: Array[String] = []
	var actions: Dictionary = _items("actions")
	for id: String in _items("combos"):
		var c: Dictionary = _items("combos")[id]
		var where := "combo '%s'" % id
		var moves: Array = c.get("moves", []) if c.get("moves") is Array else []
		if moves.size() < 2:
			problems.append("%s: a combination is two moves or more" % where)
		_expect_ids(problems, where, "actions", moves)
		for move: Variant in moves:
			var a: Dictionary = actions.get(move, {})
			if not a.is_empty() and (a.category != "strike" or not a.positions.has("standing")):
				problems.append("%s: '%s' isn't a strike thrown standing" % [where, move])
	var basic: Array = actions.keys().filter(func(a: String) -> bool: return actions[a].get("basic", false))
	var roster := FighterLibrary.load_dir()
	for id: String in _items("fighters"):
		var f: Dictionary = roster.profile(id)
		for combo: Variant in f.get("combos", []):
			for move: Variant in _items("combos").get(combo, {}).get("moves", []):
				if move not in f.get("techniques", []) and move not in basic:
					problems.append("fighter '%s': combo '%s' needs '%s', which they don't know" % [id, combo, move])
	_report(problems)


func test_training_sessions_train_real_stats_in_shares_that_add_up() -> void:
	var problems: Array[String] = []
	var stats: Dictionary = _items("enums").get("stats", {}).get("values", {})
	for id: String in _items("sessions"):
		var s: Dictionary = _items("sessions")[id]
		var where := "session '%s'" % id
		var trains: Variant = s.get("trains", {})
		if not trains is Dictionary:
			continue  # The type check reports it.
		_expect_numbers(problems, where, "trains", trains, stats.keys(), 0, 1)
		var total: float = 0.0
		for stat: Variant in trains:
			total += float(trains[stat]) if trains[stat] is float else 0.0
		if not trains.is_empty() and absf(total - 1.0) > 0.001:
			problems.append("%s: the shares in trains add up to %s, not 1" % [where, total])
		if s.get("xp") is float and (s.xp < 0.0 or (s.xp > 0.0) == trains.is_empty()):
			problems.append("%s: xp is 0 or more, and only a session that trains something has any" % where)
		if s.get("fatigue") is float and (s.fatigue < -100.0 or s.fatigue > 100.0):
			problems.append("%s: fatigue is −100 to 100 (negative takes it away)" % where)
		if s.get("injury_risk") is float and (s.injury_risk < 0.0 or s.injury_risk > 0.05):
			problems.append("%s: injury_risk is a chance per session from 0 to 0.05" % where)
		if s.get("chin_wear") is float and (s.chin_wear < 0.0 or s.chin_wear > 1.0):
			problems.append("%s: chin_wear is Chin points lost per session, 0 to 1" % where)
		_expect_numbers(problems, where, "leanings", s.get("leanings", {}), LEANINGS, -1, 1)
		var minigame: Variant = s.get("minigame")
		if minigame != null and minigame not in MINIGAMES:
			problems.append("%s: minigame '%s' is null or one of %s" % [where, minigame, MINIGAMES])
	_report(problems)


func test_week_plans_fill_six_days_of_two_sessions() -> void:
	var problems: Array[String] = []
	for id: String in _items("week_plans"):
		var p: Dictionary = _items("week_plans")[id]
		var where := "week plan '%s'" % id
		var days: Variant = p.get("days", [])
		if not days is Array or days.size() != TrainingCamp.DAYS:
			problems.append("%s: days lists Monday to Saturday (%d days)" % [where, TrainingCamp.DAYS])
			continue
		for day: Variant in days:
			if not day is Array or day.size() != TrainingCamp.SLOTS_PER_DAY:
				problems.append("%s: each day is [morning, evening]" % where)
			else:
				_expect_ids(problems, where, "sessions", day)
		var instruction: Variant = p.get("instruction")
		if instruction != null:
			_expect_ids(problems, where, "gameplans", [instruction])
	_report(problems)


# --- helpers -----------------------------------------------------------------

func _known_files() -> Array:
	return _files.keys().filter(func(p: String) -> bool:
		return _files[p] != null and SCHEMAS.has(_files[p].get("schema")))


func _items(folder: String) -> Dictionary:
	return _by_folder.get(folder, {})


## A hold's `ai_without_opening`: true or false, or a list of positions it's done from (D132).
static func _any_time_ok(value: Variant, positions: Array) -> bool:
	if value is bool:
		return true
	return value is Array and not (value as Array).is_empty() and (value as Array).all(func(p: Variant) -> bool: return p in positions)


func _expect_in(problems: Array[String], type: String, field: String, allowed: Array) -> void:
	var folder: String = ""
	for schema: String in SCHEMAS:
		if schema.begins_with(type + "@"):
			folder = SCHEMAS[schema].folder
	for id: String in _items(folder):
		var value: Variant = _items(folder)[id].get(field)
		if value not in allowed:
			problems.append("%s '%s': %s '%s' is not one of %s" % [type, id, field, value, allowed])


func _expect_ids(problems: Array[String], where: String, folder: String, ids: Array) -> void:
	for ref: Variant in ids:
		if not _items(folder).has(ref):
			problems.append("%s refers to missing %s '%s'" % [where, folder, ref])


func _expect_numbers(problems: Array[String], where: String, field: String, values: Variant, allowed_keys: Array, lo: float, hi: float) -> void:
	if not values is Dictionary:
		return  # The type check reports it.
	for key: Variant in values:
		if key not in allowed_keys:
			problems.append("%s: %s has unknown key '%s'" % [where, field, key])
		elif not (values[key] is float) or values[key] < lo or values[key] > hi:
			problems.append("%s: %s.%s must be a number from %d to %d" % [where, field, key, lo, hi])


## Weight multipliers keyed by an action id or a category, each 0–10.
func _expect_weights(problems: Array[String], where: String, field: String, values: Variant) -> void:
	if not values is Dictionary:
		problems.append("%s: %s is an object" % [where, field])
		return
	var keys: Array = CATEGORIES.duplicate()
	keys.append_array(_items("actions").keys())
	_expect_numbers(problems, where, field, values, keys, 0, 10)


func _expect_ticks(problems: Array[String], where: String, field: String, ms: Variant) -> void:
	if not ms is float or ms <= 0.0 or fmod(ms, FightClock.TICK_MS) != 0.0:
		problems.append("%s: %s must be a positive multiple of %d ms" % [where, field, FightClock.TICK_MS])


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
