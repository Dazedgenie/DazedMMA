class_name PlaytestReport
extends RefCounted
## Adds up a folder of FightRecords from the playtest (#20, D118) for the write-up
## (docs/playtests/): one CSV line per fight, and a summary per playtest fight and per
## speed with the numbers docs/10 §2 asks for. "Well-timed takedowns" are takedowns that
## worked and were chosen by the player's call or drilled rule (not the fighter's own AI).
## Run it with tools/playtest_report.gd.

const COLUMNS: Array[String] = ["file", "tester", "step", "fight", "speed", "tell_cue", "won", "result", "rounds",
	"calls", "ignored", "perfect", "td_call", "td_rule", "td_own", "catch_kicks", "rules_fired", "replays"]
## docs/10 §2 test 2: by fight 3 against the Kicker, at least this many well-timed takedowns a fight.
const LEARNED_TAKEDOWNS: int = 2


## Every fight record (fight_record@1) in a folder, oldest first, each with its file name under "file".
static func load_dir(dir_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
		if parsed is Dictionary and parsed.get("schema") == FightRecord.SCHEMA:
			parsed.file = file
			out.append(parsed)
	return out


## One record as a CSV row (COLUMNS). `replays` says whether the fight replays to the same result from its record.
static func row(record: Dictionary, check_replay: bool = true) -> Array:
	var s: Dictionary = record.get("settings", {})
	var st: Dictionary = record.get("stats", {})
	var result: Dictionary = record.get("result", {})
	var how: String = String(result.get("result", ""))
	if result.get("stopped_by", "") != "":
		how += " (%s)" % result.stopped_by
	return [record.get("file", ""), s.get("tester", ""), s.get("step", ""), s.get("label", ""), "%sx" % s.get("normal_rate", ""),
		s.get("tell_cues", ""), record.get("won", false), how, record.get("rounds_played", 0),
		st.get("calls_made", 0), st.get("calls_ignored", 0), st.get("perfect_calls", 0), st.get("takedowns_by_call", 0),
		st.get("takedowns_by_rule", 0), st.get("takedowns_own", 0), st.get("catch_kicks_landed", 0), st.get("rules_fired", 0),
		replays(record) if check_replay else ""]


static func csv(records: Array[Dictionary], check_replay: bool = true) -> String:
	var lines: Array[String] = [",".join(COLUMNS)]
	for r in records:
		lines.append(",".join(row(r, check_replay).map(func(v: Variant) -> String: return _cell(v))))
	return "\n".join(lines) + "\n"


## Does the fight replay from its record to the same ending? (docs/10 §2 "Reproducibility")
static func replays(record: Dictionary) -> bool:
	var replay: Dictionary = record.get("replay", {})
	if replay.is_empty():
		return false
	var sim: FightSim = FightSim.from_record(replay, FighterLibrary.load_dir(), ActionLibrary.load_dir())
	var ended: Dictionary = sim.events[-1].data if not sim.events.is_empty() else {}
	var wanted: Dictionary = record.get("result", {})
	return ended.get("result") == wanted.get("result") and int(ended.get("winner", -2)) == int(wanted.get("winner", -3)) \
		and sim.now == int(replay.get("ticks", sim.now))


## The write-up's numbers: per playtest fight and per speed, the fights, wins, well-timed
## takedowns and perfect calls a fight, and how many fights reached LEARNED_TAKEDOWNS.
static func summary(records: Array[Dictionary]) -> String:
	var lines: Array[String] = ["Playtest report: %d fights from %d testers" % [records.size(), _testers(records).size()], ""]
	lines.append("%-34s %6s %6s %10s %10s %10s" % ["Group", "fights", "won", "well-timed", "perfect", "2+ timed"])
	var groups := {}
	for r in records:
		var s: Dictionary = r.get("settings", {})
		var step: String = String(s.get("step", "")) if s.get("step", "") != "" else "free fights"
		for key: String in ["%s" % step, "%s at %sx" % [step, s.get("normal_rate", "?")], "all at %sx" % s.get("normal_rate", "?")]:
			if not groups.has(key):
				groups[key] = []
			groups[key].append(r)
	var keys: Array = groups.keys()
	keys.sort()
	for key: String in keys:
		var g: Array = groups[key]
		var won: int = 0
		var timed: int = 0
		var perfect: int = 0
		var learned: int = 0
		for r: Dictionary in g:
			var st: Dictionary = r.get("stats", {})
			var t: int = int(st.get("takedowns_by_call", 0)) + int(st.get("takedowns_by_rule", 0))
			won += 1 if r.get("won", false) else 0
			timed += t
			perfect += int(st.get("perfect_calls", 0))
			learned += 1 if t >= LEARNED_TAKEDOWNS else 0
		lines.append("%-34s %6d %5d%% %10.1f %10.1f %9d%%" % [key, g.size(), roundi(100.0 * won / g.size()),
			float(timed) / g.size(), float(perfect) / g.size(), roundi(100.0 * learned / g.size())])
	lines.append("")
	lines.append("well-timed: takedowns that worked from a call or a drilled rule, a fight. perfect: called moves that landed in the opening (D52), a fight.")
	lines.append("2+ timed: share of fights with %d or more well-timed takedowns (docs/10 §2 test 2 wants it by fight 3 against the Kicker)." % LEARNED_TAKEDOWNS)
	return "\n".join(lines) + "\n"


static func _testers(records: Array[Dictionary]) -> Dictionary:
	var out := {}
	for r in records:
		out[String(r.get("settings", {}).get("tester", ""))] = true
	return out


static func _cell(v: Variant) -> String:
	var text: String = str(v)
	if text.contains(",") or text.contains("\""):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text
