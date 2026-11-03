extends GutTest
## Drilling rules in camp (sim/world/rule_drilling.gd, docs/03 §13.2, D402): Drill rule sessions sharpening a slot's
## rule, rules going rusty slowly between camps, the two rules going into a career fight, and the camp's three parts.


func _career(background: String = "street_kid") -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": background, "stance": "orthodox" }, 3, FighterLibrary.load_dir())


func _report(sessions: Array, result: String = TrainingCamp.DONE) -> Dictionary:
	var slots: Array = []
	for id: String in sessions:
		slots.append({ "session": id, "result": result, "fatigue_before": 0.0 })
	return { "slots": slots }


func test_about_six_drill_sessions_take_a_rule_from_nothing_to_80_percent() -> void:
	var d: float = 0.0
	for n in 5:
		d = RuleDrilling.after_reps(d, 1.0)
	assert_lt(d, 80.0, "five isn't quite there")
	d = RuleDrilling.after_reps(d, 1.0)
	assert_between(d, 79.0, 82.0, "six is")
	assert_almost_eq(RuleDrilling.after_reps(0.0, 6.0), d, 0.001, "six at once is the same as one at a time")
	assert_lt(RuleDrilling.after_reps(d, 1.0) - d, RuleDrilling.after_reps(0.0, 1.0), "each rep adds less as it gets sharp")
	assert_lte(RuleDrilling.after_reps(99.0, 100.0), 100.0)


func test_a_drill_rule_session_done_drills_the_rule_in_its_slot_and_nothing_else_does() -> void:
	var c: Career = _career()
	assert_true(RuleDrilling.set_slot(c, 1, "sprawl_on_the_shot"))
	var report: Dictionary = _report(["drill_rule_1", "drill_rule_2", "boxing_drill"])
	c.drill_week(report)
	assert_almost_eq(RuleDrilling.drilled(c, "sprawl_on_the_shot"), RuleDrilling.after_reps(0.0, 1.0), 0.001, "slot 1's rule, once")
	assert_eq(report.drilled.keys(), ["sprawl_on_the_shot"], "slot 2 is empty: nothing drilled")
	var before: float = RuleDrilling.drilled(c, "sprawl_on_the_shot")
	c.drill_week(_report(["drill_rule_1"], TrainingCamp.SKIPPED))
	assert_eq(RuleDrilling.drilled(c, "sprawl_on_the_shot"), before, "a skipped session drills nothing")
	var worn: Dictionary = { "slots": [{ "session": "drill_rule_1", "result": TrainingCamp.DONE, "fatigue_before": 90.0 }] }
	c.drill_week(worn)
	assert_lt(float(worn.drilled.sprawl_on_the_shot[1]) - before, RuleDrilling.after_reps(before, 1.0) - before, "worn out, less sticks")


func test_a_rule_he_stops_drilling_goes_rusty_slowly_but_keeps_half_his_best() -> void:
	var c: Career = _career()
	RuleDrilling.set_slot(c, 1, "sprawl_on_the_shot")
	RuleDrilling.drill(c, "sprawl_on_the_shot", 6.0)
	var best: float = RuleDrilling.drilled(c, "sprawl_on_the_shot")
	c.end_week()
	assert_almost_eq(RuleDrilling.drilled(c, "sprawl_on_the_shot"), best, 0.001, "drilled the week that ended")
	c.end_week()
	assert_almost_eq(RuleDrilling.drilled(c, "sprawl_on_the_shot"), best - RuleDrilling.FADE_PER_WEEK, 0.001, "a week off")
	for n in 60:
		c.end_week()
	assert_almost_eq(RuleDrilling.drilled(c, "sprawl_on_the_shot"), best * RuleDrilling.KEEPS, 0.001, "never below half his best")
	var weekly: Dictionary = c.run_week()
	assert_true(weekly.has("drilled"), "weeks between fights go through the drill too")


func test_only_rules_he_knows_the_move_for_go_in_the_slots_and_into_the_fight() -> void:
	var c: Career = _career()
	assert_false(RuleDrilling.knows(c, "catch_kick_and_shoot"), "a street kid never learned the catch")
	assert_false(RuleDrilling.set_slot(c, 1, "catch_kick_and_shoot"))
	assert_true(RuleDrilling.available(c).has("sprawl_on_the_shot"), "everyone can sprawl")
	var w: Career = _career("wrestling_family")
	assert_true(RuleDrilling.knows(w, "catch_kick_and_shoot"), "the wrestler did")
	RuleDrilling.set_slot(w, 1, "catch_kick_and_shoot")
	RuleDrilling.set_slot(w, 2, "sprawl_on_the_shot")
	RuleDrilling.drill(w, "sprawl_on_the_shot", 3.0)
	assert_eq(RuleDrilling.fight_rules(w), [[1, "catch_kick_and_shoot", 0.0], [2, "sprawl_on_the_shot",
		snappedf(RuleDrilling.after_reps(0.0, 3.0), 0.1)]])
	RuleDrilling.set_slot(w, 1, "sprawl_on_the_shot")
	assert_eq(w.rule_slots, ["sprawl_on_the_shot", ""] as Array[String], "one rule in one slot")
	assert_string_contains(RuleDrilling.slots_text(w), "Rule 1: When he shoots → sprawl, drilled")


func test_his_rules_and_how_drilled_they_are_are_saved_with_the_career() -> void:
	var c: Career = _career()
	RuleDrilling.set_slot(c, 2, "sprawl_on_the_shot")
	RuleDrilling.drill(c, "sprawl_on_the_shot", 2.0)
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.rule_slots, c.rule_slots)
	assert_almost_eq(RuleDrilling.drilled(back, "sprawl_on_the_shot"), RuleDrilling.drilled(c, "sprawl_on_the_shot"), 1e-6)
	var old: Dictionary = c.to_dict()
	old.erase("rules")
	var before_d402: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_eq(before_d402.rule_slots, ["", ""] as Array[String], "a career saved before D402")
	assert_eq(before_d402.drills, {})


func test_a_camp_is_marked_early_middle_and_taper() -> void:
	var c: Career = _career()
	assert_eq(c.camp_phase(), "", "not booked")
	c.booked = { "opponent": "x", "week": c.week + 5, "camp_weeks": 6 }
	var phases: Array[String] = []
	for n in 6:
		phases.append(c.camp_phase())
		c.week += 1
	assert_eq(phases, [Career.CAMP_EARLY, Career.CAMP_EARLY, Career.CAMP_MIDDLE, Career.CAMP_MIDDLE, Career.CAMP_MIDDLE,
		Career.CAMP_TAPER] as Array[String])
	for phase: String in [Career.CAMP_EARLY, Career.CAMP_MIDDLE, Career.CAMP_TAPER]:
		assert_ne(String(Career.CAMP_PHASE_TIPS.get(phase, "")), "")


func test_the_two_drill_rule_sessions_drill_slots_one_and_two() -> void:
	var lib := TrainingLibrary.shared()
	assert_eq(RuleDrilling.slot_of(lib.session("drill_rule_1")), 1)
	assert_eq(RuleDrilling.slot_of(lib.session("drill_rule_2")), 2)
	assert_eq(RuleDrilling.slot_of(lib.session("boxing_drill")), 0)


func test_a_rule_answers_the_habit_whose_move_it_meets_or_whose_moment_it_sees_from_this_side() -> void:
	var leg := { "trigger": "own_jab_blocked", "action": "leg_kick", "chance": 0.7, "within_ms": 1500 }
	var shot := { "trigger": "opp_strike_misses", "action": "double_leg", "chance": 0.5, "within_ms": 800 }
	assert_true(RuleDrilling.answers("check_the_leg_kick", leg), "checks the kick his habit throws (D403)")
	assert_true(RuleDrilling.answers("beat_his_jab_habit", leg), "beats him to it when his jab is blocked")
	assert_false(RuleDrilling.answers("slip_the_straight", leg))
	assert_true(RuleDrilling.answers("sprawl_on_the_shot", shot))
	assert_true(RuleDrilling.answers("knee_the_shot", shot))
	assert_true(RuleDrilling.answers("hands_up_when_blocked", shot), "his habit goes off when you're blocked")
	assert_false(RuleDrilling.answers("beat_his_jab_habit", shot))


func test_the_rules_box_and_scouting_name_the_rule_that_beats_a_habit_you_have_found() -> void:
	var c: Career = _career()
	var leg := { "trigger": "own_jab_blocked", "action": "leg_kick", "chance": 0.7, "within_ms": 1500 }
	c.opponents["habit_man"] = { "id": "habit_man", "name": "Lee Marsh", "stats": {}, "tells": [leg] }
	c.booked = { "opponent": "habit_man", "week": c.week + 4, "camp_weeks": 5 }
	assert_eq(RuleDrilling.answers_found(c), [] as Array[String], "nothing found yet")
	Scouting.learn(c, "habit_man", [Scouting.key(leg)])
	var marked: Array[String] = RuleDrilling.answers_found(c)
	assert_true(marked.has("check_the_leg_kick"))
	assert_true(marked.has("beat_his_jab_habit"))
	assert_string_contains(RuleDrilling.slots_text(c), "Answers his habit: ")
	assert_string_contains(Scouting.report_text(c, c.booked_opponent(), {}, [] as Array[String]), "Drill to beat it:")


func test_every_new_rule_is_one_a_career_fighter_can_know() -> void:
	var c: Career = _career()  # A street kid: a brawler's moves.
	for id: String in ["check_the_leg_kick", "hands_up_on_the_head_kick", "beat_his_jab_habit", "hands_up_when_blocked",
			"knee_the_shot", "sprawl_on_the_shot"]:
		assert_true(RuleDrilling.knows(c, id), id)
	assert_false(RuleDrilling.knows(c, "roll_the_hook"), "the shoulder roll is a boxer's")
	assert_true(RuleDrilling.knows(_career("boxing_gym_kid"), "roll_the_hook"))
