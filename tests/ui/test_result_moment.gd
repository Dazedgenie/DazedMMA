extends GutTest
## The result as a moment (docs/06 §6.16, D436): the verdict read out over the cage, a finish playing again slowly
## behind it (game/finish_replay.gd), the judges one at a time, and a career fight's "what it means" panel.

const SAVE_DIR := "user://test_result_moment_saves/"


func after_each() -> void:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		for file in DirAccess.get_files_at(SAVE_DIR):
			DirAccess.remove_absolute(SAVE_DIR.path_join(file))


## A fight between these two run to its end with the blue corner's AI calling, as the fight screen plays one.
func _fight(red: String, blue: String, fight_seed: int) -> FightSim:
	var sim := FightSim.new(fight_seed, FighterLibrary.load_dir().make_pair(red, blue), ActionLibrary.load_dir())
	sim.corners[1] = Corner.new(Corner.AI, fight_seed)
	sim.run_to_end()
	return sim


func _finished_fight() -> FightSim:
	for s in 40:
		var sim: FightSim = _fight("brawler", "dirty_boxer", 100 + s)
		if FinishReplay.wanted(sim):
			return sim
	return null


func test_a_finish_plays_again_exactly_as_it_happened_slowly_from_another_angle() -> void:
	var sim: FightSim = _finished_fight()
	assert_not_null(sim, "a finish among 40 fights")
	var roster: FighterLibrary = FighterLibrary.load_dir()
	var replay := FinishReplay.new(sim, func() -> Array[FighterState]: return roster.make_pair("brawler", "dirty_boxer"),
		ActionLibrary.load_dir())
	var arena: ArenaView = add_child_autofree(ArenaView.new())
	replay.start(arena)
	assert_eq(arena.driver, replay.driver, "in the cage")
	assert_true(arena.backdrop, "no names over their heads")
	assert_eq(arena.view_turn, FinishReplay.VIEW_TURN, "from another angle")
	var from: int = replay.driver.sim.now
	assert_gt(from, 0, "only the last few seconds")
	assert_lte(sim.now - from, roundi(FinishReplay.SECONDS * FightClock.TICKS_PER_SECOND))
	assert_eq(replay.driver.rate(), FinishReplay.RATE, "slowly")
	var guard: int = 0
	while not replay.driver.sim.is_over() and guard < 10000:
		replay.advance(arena, 0.1)
		guard += 1
	replay.advance(arena, 0.1)
	assert_eq(replay.driver.sim.now, sim.now, "ends on the same tick")
	assert_eq(JSON.stringify(replay.driver.sim.events[-1].data), JSON.stringify(sim.events[-1].data), "and the same way")
	assert_true(replay.exact)
	replay.advance(arena, FinishReplay.HOLD_AFTER)
	assert_eq(replay.plays, 2, "held, then again")
	replay.stop(arena)
	assert_null(arena.driver)
	assert_eq(arena.view_turn, 0.0, "the camera back as it was")


func test_only_a_finish_is_replayed() -> void:
	for s in 40:
		var sim: FightSim = _fight("check_red", "check_blue", 300 + s)
		var ended: String = String(sim.events[-1].data.result)
		assert_eq(FinishReplay.wanted(sim), ended in [FightSim.RESULT_KO, FightSim.RESULT_TKO, FightSim.RESULT_SUB], ended)


func test_a_decision_is_read_out_one_judge_at_a_time_then_the_winner() -> void:
	var sim: FightSim = null
	for s in 40:
		sim = _fight("check_red", "check_blue", 500 + s)
		if sim.events[-1].data.has("cards") and int(sim.events[-1].data.get("winner", -1)) >= 0:
			break
	assert_true(sim.events[-1].data.has("cards"), "a decision among 40 fights")
	var lines: Array[Array] = VerdictBanner.read_out(sim)
	var judges: int = (sim.events[-1].data.cards as Array).size()
	assert_eq(lines.size(), judges + 3, "to the cards, each judge, the winner, how")
	for j in judges:
		assert_string_contains(String(lines[1 + j][0]), "Judge %d" % (j + 1))
	var winner: int = int(sim.events[-1].data.winner)
	assert_eq(String(lines[-2][0]), "%s WINS" % sim.fighters[winner].name.to_upper())
	var banner: VerdictBanner = add_child_autofree(VerdictBanner.new())
	watch_signals(banner)
	banner.begin(sim)
	assert_eq(banner.shown, 1, "one line at a time")
	banner._process(VerdictBanner.READ_GAP + 0.01)
	assert_eq(banner.shown, 2)
	for i in judges:
		banner._process(VerdictBanner.READ_GAP + 0.01)
	assert_true(banner.all_shown(), "the winner's name comes up with how it was decided")
	banner._process(VerdictBanner.STAY_FOR + 0.01)
	assert_signal_emitted(banner, "finished", "goes on by itself")


func test_a_key_shows_the_verdict_all_at_once_and_another_goes_on() -> void:
	var sim: FightSim = _finished_fight()
	var banner: VerdictBanner = add_child_autofree(VerdictBanner.new())
	watch_signals(banner)
	banner.begin(sim, true)
	assert_eq(VerdictBanner.read_out(sim).size(), 2, "how and when, then the winner")
	assert_true(banner._replay.visible, "REPLAY in the corner")
	banner.skip()
	assert_true(banner.all_shown())
	assert_signal_not_emitted(banner, "finished")
	banner.skip()
	assert_signal_emitted(banner, "finished")
	assert_false(banner.visible)


func test_a_career_fight_says_what_it_did_to_him() -> void:
	var before := { "record": "8-1-0", "pro": true, "rank": 2, "belt": "", "money": 1000 }
	var after := { "record": "9-1-0", "pro": true, "rank": 2, "belt": "the IML welterweight title", "money": 6000,
		"promotion": "International MMA League" }
	var fight := { "result": "win", "title": "iml:welterweight", "purse": 5000, "moved": "up" }
	var rows: Array = FightResultCard.meaning_rows(before, after, fight, "Medical suspension: 7 days.")
	var text: String = "\n".join(rows.map(func(r: Array) -> String: return "%s %s" % r))
	assert_string_contains(text, "8-1-0 → ")
	assert_string_contains(text, "9-1-0")
	assert_string_contains(text, "#2")
	assert_string_contains(text, "Won the IML welterweight title")
	assert_string_contains(text, "Called up to International MMA League")
	assert_string_contains(text, "$5000")
	assert_string_contains(text, "Medical suspension: 7 days.")
	var lost: Array = FightResultCard.meaning_rows(after, before, { "result": "loss", "title": "iml:welterweight" }, "")
	assert_string_contains("\n".join(lost.map(func(r: Array) -> String: return String(r[1]))), "Lost the IML welterweight title")
	var amateur: Array = FightResultCard.meaning_rows({ "record": "0-0-0", "pro": false }, { "record": "1-0-0", "pro": false },
		{ "result": "win" }, "")
	assert_eq(amateur.size(), 1, "an amateur: just his record")


func test_the_fight_screen_reads_the_verdict_over_the_finish_before_the_sheet() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.verdict_in_headless = true
	add_child_autofree(main)
	main.save_dir = SAVE_DIR
	main.record_dir = ""
	var s: Dictionary = main.setup.settings()
	s.seed = 11
	main.start_fight(s)
	main.driver.throw_towel()  # A TKO: a finish to see again.
	await wait_process_frames(1)
	assert_eq(main.state, main.OVER)
	assert_true(main.verdict.visible, "the verdict over the cage")
	assert_false(main.result.visible, "the sheet waits")
	assert_false(main.hud.visible)
	assert_true(main.replay != null and main.replay.running(), "the finish again behind it")
	assert_eq(main.arena.driver, main.replay.driver)
	main.verdict.skip()
	main.verdict.skip()
	await wait_process_frames(1)
	assert_true(main.result.visible, "then the sheet")
	assert_true(main.replay.running(), "the finish still playing behind the sheet")
	main.start_fight(s)
	assert_null(main.replay, "a new fight has the cage")
	assert_eq(main.arena.driver, main.driver)
