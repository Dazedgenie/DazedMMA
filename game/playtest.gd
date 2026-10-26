class_name Playtest
extends RefCounted
## The playtest's fights in order (#20, D118, docs/playtests/): data/playtest/*.json
## (playtest@1), a mini version of the onboarding steps 4–9 (docs/07 §3) so every
## tester learns the calls in the same order: three calls first, then the read call
## against the Kicker with the tell cue, then a drilled rule and the full call bar.

const DEFAULT_DIR := "res://data/playtest/"


## Every step, in order: [{id, name, order, red, blue, calls, rules, tell_cue, tip}, …].
static func steps(dir_path: String = DEFAULT_DIR) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file in files:
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			if parsed is Dictionary:
				out.append(parsed)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.order) < float(b.order))
	return out


## The fight settings (FightSetup.settings()) for a step: its matchup, calls, rules, tell cue and tip,
## keeping the rest of `base` (speed, difficulty, the other toggles, the tester's name).
static func settings_for(step: Dictionary, base: Dictionary = {}) -> Dictionary:
	var s: Dictionary = base.duplicate(true)
	s.step = String(step.id)
	s.label = String(step.name)
	s.red = String(step.red)
	s.blue = String(step.blue)
	s.calls = Array(step.get("calls", []))
	s.tell_cues = bool(step.get("tell_cue", true))
	s.tip = String(step.get("tip", ""))
	var rules: Array = []
	for slot in DrilledRules.MAX_SLOTS:
		var entry: Array = step.rules[slot] if slot < step.get("rules", []).size() else ["", 80.0]
		rules.append([slot + 1, String(entry[0]), float(entry[1])])
	s.rules = rules
	return s


## The step after this one, or {} after the last.
static func next_step(id: String, dir_path: String = DEFAULT_DIR) -> Dictionary:
	var all: Array[Dictionary] = steps(dir_path)
	for n in all.size() - 1:
		if all[n].id == id:
			return all[n + 1]
	return {}
