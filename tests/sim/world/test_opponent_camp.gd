extends GutTest
## The opponent's camp (sim/world/opponent_camp.gd, docs/03 §13.8, D404): the plan his corner rolls from his style's
## list, a rule against your favourite move (more often higher up), his tank, and when you get to see it.


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


## Books him a man made from the Kicker's sheet, `weeks` from now.
func _book(c: Career, weeks: int = 4, id: String = "camp_test_man") -> Dictionary:
	var him: Dictionary = { "id": id, "name": "Lee Marsh", "style_id": "kicker", "stats": { "kicking": 70.0 }, "techniques": [] }
	c.opponents[id] = him
	c.booked = { "opponent": id, "week": c.week + weeks - 1, "camp_weeks": weeks }
	return him


## Three fights on his record in which he threw `moves`.
func _fought(c: Career, moves: Dictionary, fights: int = 3) -> void:
	for i in fights:
		c.fights.append({ "opponent": "someone_%d" % i, "result": "win", "week": i, "moves": moves.duplicate() })


func test_the_same_booking_always_gives_the_same_camp_and_his_plan_is_one_of_his_styles() -> void:
	var c: Career = _career()
	var him: Dictionary = _book(c)
	assert_eq(OpponentCamp.of(c), OpponentCamp.of(c), "seeded by the booking")
	var plans: Array[Dictionary] = StyleLibrary.gameplans_of(him)
	assert_eq(plans.size(), 3, "the kicker's plan and its two others (D404)")
	var seen: Dictionary = {}
	for s in 60:
		c.career_seed = s
		var plan: Dictionary = OpponentCamp.of(c).plan
		assert_true(plans.has(plan), "one of his style's plans")
		seen[str(plan)] = true
	assert_eq(seen.size(), 3, "each of them comes up")


func test_your_favourite_move_is_the_one_you_threw_most_lately_that_a_rule_answers() -> void:
	var c: Career = _career()
	assert_eq(OpponentCamp.favourite_move(c), "", "no fights: no film of him")
	c.fights.append({ "opponent": "a", "result": "win", "week": 0, "moves": { "double_leg": 40 } })
	_fought(c, { "uppercut": 60, "leg_kick": 12, "hook": 9 })
	assert_eq(OpponentCamp.favourite_move(c), "leg_kick", "no rule answers the uppercut, and the old fight's shots are forgotten")
	assert_false(OpponentCamp.answerable("uppercut"))
	assert_true(OpponentCamp.answerable("jab"), "a slip meets a jab")
	assert_true(OpponentCamp.answerable("leg_kick"))
	assert_true(OpponentCamp.answers_to("leg_kick", {}).has("check_the_leg_kick"), "anyone can check")


func test_he_drills_a_rule_against_it_a_third_of_the_time_as_an_amateur_half_as_a_pro_and_always_for_a_title() -> void:
	var c: Career = _career()
	_book(c)
	_fought(c, { "leg_kick": 20 })
	var count := func() -> int:
		var n: int = 0
		for s in 300:
			c.career_seed = s
			var camp: Dictionary = OpponentCamp.of(c)
			if String(camp.rule) != "":
				n += 1
				assert_eq(String(camp.move), "leg_kick")
				assert_true(RuleDrilling.answers(String(camp.rule), { "action": "leg_kick" }), "it answers your leg kick")
				assert_between(float(camp.drilled), OpponentCamp.DRILLED_MIN, OpponentCamp.DRILLED_MAX)
		return n
	assert_between(count.call(), 75, 125, "about a third of amateurs")
	c.pro = true
	assert_between(count.call(), 125, 175, "about half of pros")
	c.booked.title = "some_belt"
	assert_eq(count.call(), 300, "every title fight")


func test_most_come_in_fresh_and_some_overtrained() -> void:
	var c: Career = _career()
	_book(c)
	var tired: int = 0
	for s in 400:
		c.career_seed = s
		var tank: float = float(OpponentCamp.of(c).tank)
		if tank < 1.0:
			tired += 1
			assert_between(tank, OpponentCamp.TANK_LOW - 0.0001, OpponentCamp.TANK_HIGH + 0.0001)
	assert_between(tired, 70, 130, "about a quarter")


func test_no_camp_in_a_tournament_or_with_nobody_booked() -> void:
	var c: Career = _career()
	assert_eq(OpponentCamp.of(c), {}, "nobody booked")
	_book(c)
	c.booked.tournament = { "size": 4, "stage": 0, "men": [] }
	assert_eq(OpponentCamp.of(c), {}, "one day: nobody prepared for him")


func test_you_see_it_early_only_in_fight_week_and_only_when_you_know_him_well() -> void:
	var c: Career = _career()
	var him: Dictionary = _book(c, 1)
	assert_false(OpponentCamp.known_early(c), "fight week, but you don't know him")
	c.scouting[String(him.id)] = { "known": OpponentCamp.SCOUTED_EARLY }
	assert_true(OpponentCamp.known_early(c))
	_book(c, 3)
	c.scouting["camp_test_man"] = { "known": 1.0 }
	assert_false(OpponentCamp.known_early(c), "known, but it's not fight week yet")


func test_his_camp_reads_as_his_plan_his_rule_and_his_tank() -> void:
	var lines: Array[String] = OpponentCamp.lines({ "plan": { "approach": "pressure", "target": "body", "where": "" },
		"rule": "check_the_leg_kick", "drilled": 64.0, "move": "leg_kick", "tank": 0.9 })
	assert_eq(lines[0], "His plan: Pressure · Body.")
	assert_string_contains(lines[1], "He's drilled When he leg kicks → check it (64%) for your leg kick.")
	assert_eq(lines[2], "He overtrained: 90% of his gas tank.")
	assert_string_contains(OpponentCamp.lines({ "plan": {}, "rule": "", "move": "", "tank": 1.0 })[1], "no film of you")
	assert_eq(OpponentCamp.lines({}), [] as Array[String])


func test_the_moves_he_started_in_a_fight_are_counted() -> void:
	var sim := FightSim.new(7, [FighterState.new("Red"), FighterState.new("Blue")], ActionLibrary.load_dir())
	sim.events.append(FightEvent.new(0, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "leg_kick", "phase": "telegraph" }))
	sim.events.append(FightEvent.new(1, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "leg_kick", "phase": "active" }))
	sim.events.append(FightEvent.new(2, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "jab", "phase": "telegraph" }))
	sim.events.append(FightEvent.new(3, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "leg_kick", "phase": "telegraph" }))
	assert_eq(OpponentCamp.moves_of(sim, 0), { "leg_kick": 2 })
