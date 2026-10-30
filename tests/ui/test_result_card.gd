extends GutTest
## The result screen (ui/result_card.gd, D173, docs/06 §6.8): the verdict and when, both figures as they finished,
## the fight sheet, the judges' cards round by round, and your corner's grade.

var _roster: FighterLibrary
var _actions: ActionLibrary
var _card: FightResultCard


func before_all() -> void:
	_roster = FighterLibrary.load_dir()
	_actions = ActionLibrary.load_dir()


func before_each() -> void:
	_card = FightResultCard.new()
	add_child_autofree(_card)


## The first of these seeds whose Wrestler vs Boxer fight went the distance (`decision`) or didn't.
func _fight(decision: bool) -> FightSim:
	for fight_seed in range(1, 40):
		var sim := FightSim.new(fight_seed, _roster.make_pair("wrestler", "boxer"), _actions)
		sim.run_to_end()
		var finished: bool = String(sim.events[-1].data.result) in FightResultCard.FINISHES
		if finished != decision:
			return sim
	fail_test("no %s in 40 seeds" % ("decision" if decision else "finish"))
	return null


## A fight that hasn't run, with these events in it.
func _staged(events: Array[FightEvent]) -> FightSim:
	var sim := FightSim.new(1, _roster.make_pair("wrestler", "boxer"), _actions)
	sim.events.clear()
	sim.events.append_array(events)
	return sim


func test_a_decision_shows_the_winner_the_cards_round_by_round_and_the_totals() -> void:
	var sim: FightSim = _fight(true)
	_card.show_result(sim, 0, {}, [], [["Fight again", func() -> void: pass]])
	var ended: Dictionary = sim.events[-1].data
	var text: String = _card.text()
	var winner: int = int(ended.winner)
	assert_string_contains(text, "%s WINS" % sim.fighters[winner].name.to_upper() if winner >= 0 else "DRAW")
	assert_string_contains(text, "after 3 rounds")
	assert_string_contains(text, "Round 3")
	assert_string_contains(text, "Total")
	for card: Array in ended.cards:
		assert_string_contains(text, "%d-%d" % [card[0], card[1]])


func test_a_finish_says_the_round_and_time_and_that_the_cards_didnt_decide_it() -> void:
	var sim: FightSim = _fight(false)
	_card.show_result(sim, 0, {}, [], [])
	var seconds: int = sim.clock.tick_in_round / FightClock.TICKS_PER_SECOND
	assert_string_contains(_card.text(), "Round %d, %d:%02d" % [sim.clock.current_round, seconds / 60, seconds % 60])
	var judged: String = FightResultCard.judges_bbcode(sim)
	assert_true(judged.contains("Stopped in round") or judged.contains("Over before the judges"), judged)


func test_the_sheet_counts_every_strike_and_takedown_the_fighters_did() -> void:
	var sim: FightSim = _fight(true)
	var numbers: Array[Dictionary] = FightResultCard.sheet(sim)
	for i in 2:
		var landed: int = 0
		for area: String in FightResultCard.AREAS:
			landed += int(numbers[i].strikes[area][0])
		assert_eq(landed, sim.fighters[i].strikes_landed)
		assert_eq(numbers[i].takedowns, [sim.fighters[i].takedowns_landed, sim.fighters[i].takedowns_tried])
	var rows: Array[Dictionary] = FightResultCard.sheet_rows(numbers)
	assert_eq(rows[0].label, "STRIKES LANDED")


func test_control_time_is_the_time_on_top_or_holding_a_submission() -> void:
	var sim: FightSim = _staged([
		FightEvent.new(100, 1, FightEvent.POSITION_CHANGED, 0, { "roles": ["top", "bottom"] }),
		FightEvent.new(400, 1, FightEvent.POSITION_CHANGED, 1, { "roles": ["defender", "attacker"] }),
		FightEvent.new(500, 1, FightEvent.ROUND_ENDED, FightEvent.NO_ACTOR, {}),
		FightEvent.new(600, 2, FightEvent.KNOCKDOWN, 1, { "by": 0 }),
		FightEvent.new(700, 2, FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR, { "result": "tko", "winner": 0 }),
	])
	var numbers: Array[Dictionary] = FightResultCard.sheet(sim)
	assert_almost_eq(float(numbers[0].control_s), 30.0, 0.01, "on top from tick 100 to 400")
	assert_almost_eq(float(numbers[1].control_s), 10.0, 0.01, "the hold, until the round ended")
	assert_eq([numbers[0].knockdowns, numbers[1].knockdowns], [1, 0], "a knockdown counts for who scored it")
	assert_eq(FightResultCard.sheet_rows(numbers).filter(func(r: Dictionary) -> bool: return r.get("label", "") == "CONTROL TIME")[0].red, "0:30")


func test_whole_fight_judging_says_what_each_judge_went_on() -> void:
	var sim: FightSim = _staged([FightEvent.new(10, 1, FightEvent.FIGHT_ENDED, FightEvent.NO_ACTOR,
		{ "result": Judging.SPLIT, "winner": 0, "judges": [0, 1, 0], "judged_on": ["control", "finish", "aggression"] })])
	var text: String = FightResultCard.judges_bbcode(sim)
	assert_string_contains(text, "Judge 1: [color=")
	assert_string_contains(text, "Wrestler[/color] on control")
	assert_string_contains(text, "Boxer[/color] on the effort to finish")


func test_the_corner_grade_rises_with_good_calls_and_falls_with_ignored_ones() -> void:
	var good: Dictionary = FightResultCard.corner_grade({ "calls_made": 6, "perfect_calls": 2, "takedowns_by_call": 2 })
	assert_eq(good.points, 50.0 + 2 * 8.0 + 2 * 6.0)
	assert_eq(good.grade, "A")
	var ignored: Dictionary = FightResultCard.corner_grade({ "calls_made": 6, "calls_ignored": 4 })
	assert_eq(ignored.points, 30.0)
	assert_eq(ignored.grade, "D")
	assert_eq(FightResultCard.corner_grade({}).grade, "–", "no calls, no grade")
	assert_eq(FightResultCard.corner_grade({ "calls_made": 40, "calls_ignored": 40 }).points, 0.0, "never below 0")


func test_the_buttons_are_the_ones_given_and_pressing_runs_them() -> void:
	var sim: FightSim = _fight(true)
	var pressed: Array[String] = []
	_card.show_result(sim, 0, { "calls_made": 2, "perfect_calls": 1 }, ["Seed 7"],
		[["Fight again", func() -> void: pressed.append("again")], ["Change setup", func() -> void: pressed.append("setup")]])
	assert_eq(_card.button_labels(), ["Fight again", "Change setup"] as Array[String])
	_card.press(1)
	assert_eq(pressed, ["setup"] as Array[String])
	assert_string_contains(_card.text(), "Corner B")
	assert_string_contains(_card.text(), "Seed 7")
	_card.show_result(sim, 0, {}, [], [["Only", func() -> void: pass]])
	assert_eq(_card.button_labels(), ["Only"] as Array[String], "showing it again replaces the buttons")
