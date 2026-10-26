extends GutTest
## Golden fights (#35, D122, docs/01 §2.2): whole fights whose results and event
## hash are pinned in tests/golden/golden_fights.json. A change that alters any of
## them fails here until it's re-pinned on purpose.

const HOW_TO_UPDATE := "If the change is meant to change fights, run `godot --headless --script res://tools/golden.gd -- --update`, commit tests/golden/golden_fights.json and say why in the PR (docs/01 §2.2)."

var _roster: FighterLibrary
var _actions: ActionLibrary
var _entries: Array[Dictionary] = []
## One GoldenFights.play() result per entry; each fight is played once for all the tests.
var _played: Array[Dictionary] = []


func before_all() -> void:
	_roster = FighterLibrary.load_dir()
	_actions = ActionLibrary.load_dir()
	_entries = GoldenFights.load_cases()
	for entry in _entries:
		_played.append(GoldenFights.play(entry, _roster, _actions))


func test_every_golden_fight_plays_out_exactly_as_pinned() -> void:
	assert_gt(_entries.size(), 0, "no golden fights in %s" % GoldenFights.PATH)
	for n in _entries.size():
		var diffs: Array[String] = GoldenFights.differences(_entries[n].get("pinned", {}), _played[n].pinned)
		assert_eq(diffs, [] as Array[String], "Golden fight '%s' changed: %s. %s" % [
			_entries[n].name, "; ".join(diffs), HOW_TO_UPDATE])


func test_every_golden_fight_replays_from_its_seed_and_command_log() -> void:
	for n in _entries.size():
		var sim: FightSim = _played[n].sim
		var again: FightSim = FightSim.from_record(JSON.parse_string(JSON.stringify(sim.record())), _roster, _actions)
		assert_eq(GoldenFights.event_hash(again), GoldenFights.event_hash(sim),
			"'%s' played differently from its saved record" % _entries[n].name)


func test_the_golden_fights_cover_calls_drilled_rules_takedowns_finishes_and_decisions() -> void:
	var seen := {}
	for p: Dictionary in _played:
		var row: Dictionary = p.row
		if row.calls_red + row.calls_blue > 0:
			seen["live calls"] = true
		if row.fired_red + row.fired_blue > 0:
			seen["drilled rules firing"] = true
		if row.takedowns_red + row.takedowns_blue > 0:
			seen.takedowns = true
		if row.method in [FightSummary.METHOD_KO, FightSummary.METHOD_TKO]:
			seen["a KO or TKO"] = true
		if row.method == FightSummary.METHOD_DECISION:
			seen["a decision"] = true
		if row.ruleset != Ruleset.DEFAULT_ID:
			seen["a ruleset other than pro"] = true
	for what: String in ["live calls", "drilled rules firing", "takedowns", "a KO or TKO", "a decision", "a ruleset other than pro"]:
		assert_true(seen.get(what, false), "no golden fight has %s any more: pick another seed in %s" % [what, GoldenFights.PATH])


func test_a_changed_pin_is_reported_in_plain_words() -> void:
	var pinned: Dictionary = _played[0].pinned.duplicate()
	pinned.landed_red = int(pinned.landed_red) + 1
	pinned[GoldenFights.EVENT_HASH] = "0"
	var diffs: Array[String] = GoldenFights.differences(pinned, _played[0].pinned)
	assert_eq(diffs.size(), 2)
	assert_eq(diffs[0], "landed_red was %d, now %d" % [pinned.landed_red, _played[0].pinned.landed_red])
	assert_string_starts_with(diffs[1], "the event list changed")


func test_numbers_read_back_from_json_still_match() -> void:
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(_played[0].pinned))
	assert_eq(GoldenFights.differences(round_trip, _played[0].pinned), [] as Array[String])
