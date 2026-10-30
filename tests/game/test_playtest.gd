extends GutTest
## Playtest, FightRecord and PlaytestReport: the playtest kit (#20, D118, docs/playtests/).

const TEST_DIR := "user://test_fight_records/"

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func after_each() -> void:
	for file in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file))


func test_the_playtest_fights_follow_the_onboarding_order() -> void:
	var steps: Array[Dictionary] = Playtest.steps()
	assert_eq(steps.map(func(s: Dictionary) -> String: return s.id), ["fight_1_first_calls", "fight_2_catch_the_kick", "fight_3_drilled_rule"])
	assert_eq(steps[0].calls, ["pressure", "circle_out", "takedown", "ground_and_pound", "go_for_the_finish", "finish_it", "defend_the_sub"],
		"three call keys first (docs/07 step 4; on top Ground and pound! and Go for the finish! share keys 1 and 2, Finish it! and Defend the sub! are only live in a hold)")
	assert_true(steps[1].calls.has("catch_the_kick"), "then the read call against the Kicker (step 7)")
	for step in steps.slice(0, 2):
		assert_true(step.calls.has("finish_it") and step.calls.has("defend_the_sub"), "both sub calls wherever a hold can lock (D126, D127)")
		assert_true(step.calls.has("go_for_the_finish"), "and the call that goes for one (D200)")
	assert_eq(steps[2].calls, [], "then the full call bar (step 9)")
	assert_eq(Playtest.next_step("fight_1_first_calls").id, "fight_2_catch_the_kick")
	assert_eq(Playtest.next_step("fight_3_drilled_rule"), {})


func test_a_step_sets_the_fight_and_keeps_the_testers_own_settings() -> void:
	var s: Dictionary = Playtest.settings_for(Playtest.steps()[2], { "normal_rate": 1.0, "tester": "Sam", "easy": true })
	assert_eq([s.red, s.blue], ["wrestler", "kicker"])
	assert_eq(s.rules, [[1, "catch_kick_and_shoot", 80.0], [2, "", 80.0]])
	assert_eq(s.normal_rate, 1.0)
	assert_eq(s.tester, "Sam")
	assert_true(s.tip.length() > 0)


func _played(fight_seed: int = 4) -> FightSim:
	var sim := FightSim.new(fight_seed, _roster.make_pair("wrestler", "kicker"), _actions)
	sim.corners[1] = Corner.new(Corner.AI, fight_seed)
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 80.0))
	for t in range(20, 9000, 60):
		sim.submit(FightCommand.live_call(t, 0, "catch_the_kick"))
	sim.run_to_end()
	return sim


func test_a_fight_record_counts_the_coaching_and_replays_the_fight() -> void:
	var sim: FightSim = _played()
	var record: Dictionary = FightRecord.build(sim, { "step": "fight_3_drilled_rule", "tester": "Sam", "normal_rate": 2.0, "seed": 4 })
	var st: Dictionary = record.stats
	assert_gt(st.calls_made, 0, "calls until the fight ended (it can end early, D120)")
	assert_eq(st.calls_by_id.catch_the_kick, st.calls_made)
	assert_gt(st.takedowns_by_call + st.takedowns_by_rule, 0, "the read and the rule catch kicks")
	assert_gt(st.catch_kicks_landed, 0)
	assert_eq(record.settings.keys().has("seed"), false, "only the settings worth keeping")
	assert_true(PlaytestReport.replays(JSON.parse_string(JSON.stringify(record))), "saved as JSON, it replays to the same ending")


func test_records_save_as_json_and_the_report_adds_them_up() -> void:
	var a: String = FightRecord.save(FightRecord.build(_played(4), { "step": "fight_2_catch_the_kick", "tester": "Sam", "normal_rate": 2.0 }), TEST_DIR)
	var b: String = FightRecord.save(FightRecord.build(_played(5), { "step": "fight_2_catch_the_kick", "tester": "Alex", "normal_rate": 1.0 }), TEST_DIR)
	assert_ne(a, "")
	assert_string_contains(a.get_file(), "sam_fight_2_catch_the_kick_seed4")
	var records: Array[Dictionary] = PlaytestReport.load_dir(TEST_DIR)
	assert_eq(records.size(), 2)
	var csv: String = PlaytestReport.csv(records)
	assert_eq(csv.split("\n")[0], ",".join(PlaytestReport.COLUMNS))
	assert_string_contains(csv, ",true\n", "both replay")
	var summary: String = PlaytestReport.summary(records)
	assert_string_contains(summary, "2 fights from 2 testers")
	assert_string_contains(summary, "fight_2_catch_the_kick at 1.0x")
	assert_string_contains(summary, "fight_2_catch_the_kick at 2.0x")
