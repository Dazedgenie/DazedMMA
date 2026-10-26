class_name GoldenFights
extends RefCounted
## Golden fights (#35, D122, docs/01 §2.2): a few whole fights whose results and
## event hash are pinned in tests/golden/golden_fights.json. Any change to a
## balance number, the AI, the corners or the rules that changes a fight fails
## tests/sim/balance/test_golden_fights.gd until the pins are updated on purpose
## with tools/golden.gd -- --update, so the change shows up in the PR (R9).
##
## Each entry sets up a fight the way the balance harness does (FightSummary.setup:
## seed, data/fighters ids, ruleset, coaching bots, drilled rules) and pins the
## PINNED columns of its FightSummary row plus `event_hash`.

const PATH := "res://tests/golden/golden_fights.json"
const ABOUT := "Golden fights (#35, D122, docs/01 §2.2). Edit the setup by hand; never the pinned numbers: run godot --headless --script res://tools/golden.gd -- --update."
## The FightSummary columns pinned for each fight, so a failure says what changed
## in plain numbers. `event_hash` catches everything else.
const PINNED: Array[String] = [
	"winner_id", "method", "result", "end_round", "end_second", "events",
	"knockdowns_red", "knockdowns_blue", "thrown_red", "landed_red", "thrown_blue", "landed_blue",
	"takedowns_red", "takedowns_blue", "calls_red", "calls_blue", "fired_red", "fired_blue",
]
const EVENT_HASH := "event_hash"


## Every entry in the file, in order. Setup keys: name, seed, red, blue,
## ruleset, corners ([red, blue] Corner styles), rules ([red, blue] lists of
## "rule_id@drilled"), and pinned (written by update()).
static func load_cases(path: String = PATH) -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary and parsed.has("fights"), "no golden fights in %s" % path)
	var out: Array[Dictionary] = []
	for entry: Dictionary in parsed.fights:
		out.append(entry)
	return out


## Plays one entry from scratch. Returns `sim` (the finished fight), `row`
## (its FightSummary row) and `pinned` (what the file would pin for it now).
static func play(entry: Dictionary, roster: FighterLibrary, actions: ActionLibrary) -> Dictionary:
	var corners: Array[String] = []
	for style: String in entry.get("corners", []):
		corners.append(style)
	var sim: FightSim = FightSummary.setup(int(entry.seed), roster, actions, entry.red, entry.blue,
		Ruleset.load_id(entry.get("ruleset", Ruleset.DEFAULT_ID)), 300, corners, entry.get("rules", []))
	var row: Dictionary = FightSummary.play(sim)
	return { "sim": sim, "row": row, "pinned": pins_for(sim, row) }


## What gets pinned for a finished fight and its row.
static func pins_for(sim: FightSim, row: Dictionary) -> Dictionary:
	var pins := {}
	for column: String in PINNED:
		pins[column] = row[column]
	pins[EVENT_HASH] = event_hash(sim)
	return pins


## The hash of a fight's whole event list (the same one D105 speed work is checked with).
static func event_hash(sim: FightSim) -> String:
	return JSON.stringify(sim.events_as_dicts()).md5_text()


## One plain line per pinned value that differs, e.g. "landed_red was 52, now 49".
## Empty when the fight played out exactly as pinned.
static func differences(pinned: Dictionary, now: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if pinned.is_empty():
		return ["not pinned yet"]
	for key: String in now:
		if key == EVENT_HASH:
			continue
		if not pinned.has(key):
			out.append("%s isn't pinned yet (now %s)" % [key, _show(now[key])])
		elif not _same(pinned[key], now[key]):
			out.append("%s was %s, now %s" % [key, _show(pinned[key]), _show(now[key])])
	if pinned.get(EVENT_HASH, "") != now[EVENT_HASH]:
		out.append("the event list changed (event hash %s, now %s)" % [pinned.get(EVENT_HASH, "none"), now[EVENT_HASH]])
	return out


## Writes the entries back with fresh pins. `pins` holds one pinned dictionary
## per entry, in order. Setup keys keep a fixed order so diffs stay small.
static func save(entries: Array[Dictionary], pins: Array[Dictionary], path: String = PATH) -> Error:
	var fights: Array = []
	for n in entries.size():
		var e: Dictionary = entries[n]
		var pinned := {}
		for key: String in PINNED + [EVENT_HASH]:
			pinned[key] = pins[n][key]
		fights.append({ "name": e.name, "seed": int(e.seed), "red": e.red, "blue": e.blue,
			"ruleset": e.get("ruleset", Ruleset.DEFAULT_ID), "corners": e.get("corners", []), "rules": e.get("rules", []),
			"pinned": pinned })
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({ "about": ABOUT, "fights": fights }, "\t", false) + "\n")
	return OK


## Numbers read back from JSON are floats; 52 and 52.0 are the same pin.
static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	return a == b


## A pin as it reads in the file: 3, not 3.0.
static func _show(v: Variant) -> String:
	return str(int(v)) if v is float and v == floorf(v) else str(v)
