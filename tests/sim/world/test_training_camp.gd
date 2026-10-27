extends GutTest
## TrainingCamp: week plans of sessions turn into attribute points, fatigue,
## style pushes, chin wear and camp injuries (docs/02 §3.5, D125).


func _fighter(overrides: Dictionary = {}) -> Dictionary:
	var f := {
		"id": "trainee", "name": "Trainee", "template": null,
		"stats": { "boxing": 40, "takedowns": 40, "durability": 50, "recovery": 50, "chin": 60 },
		"personality": { "ego": 0, "discipline": 0, "coachable": 0, "loyal": 0 },
		"style": { "pace": 0, "range": 0, "base": 0, "risk": 0 },
		"gifts": [], "flaws": [], "age": 25, "potential": 75,
	}
	f.merge(overrides, true)
	return f


## The data library with nobody getting hurt, for tests where a random camp injury would get in the way.
func _no_injuries() -> TrainingLibrary:
	var library := TrainingLibrary.load_dirs()
	for id in library.session_ids():
		var session: Dictionary = library.session(id).duplicate(true)
		session.injury_risk = 0.0
		library.add_session(session)
	return library


## That library plus a test plan: one session on Monday morning and rest everywhere else.
func _library_with(id: String, monday_morning: String, instruction: Variant = null) -> TrainingLibrary:
	var library := _no_injuries()
	var days: Array = []
	for d in TrainingCamp.DAYS:
		days.append([monday_morning if d == 0 else "rest", "rest"])
	library.add_plan({ "id": id, "name": id, "instruction": instruction, "days": days })
	return library


func _all_week(library: TrainingLibrary, id: String, session: String) -> void:
	var days: Array = []
	for d in TrainingCamp.DAYS:
		days.append([session, session])
	library.add_plan({ "id": id, "name": id, "instruction": null, "days": days })


func test_the_same_fighter_plans_and_seed_train_exactly_the_same() -> void:
	var plans: Array[String] = ["balanced", "balanced", "all_out", "taper"]
	var a := TrainingCamp.new(_fighter(), 7)
	var b := TrainingCamp.new(_fighter(), 7)
	assert_eq(JSON.stringify(a.run_camp(plans)), JSON.stringify(b.run_camp(plans)))
	assert_eq(JSON.stringify(a.profile()), JSON.stringify(b.profile()))


func test_a_session_raises_the_stats_it_trains_and_nothing_else() -> void:
	var camp := TrainingCamp.new(_fighter(), 1, _library_with("one_drill", "boxing_drill"))
	var week: Dictionary = camp.run_week("one_drill")
	assert_gt(camp.stat("boxing"), 40.0)
	assert_gt(camp.stat("footwork"), 50.0)
	assert_gt(camp.stat("striking_defense"), 50.0)
	assert_eq(camp.stat("takedowns"), 40.0)
	assert_eq(week.gains.keys().size(), 3)


func test_higher_stats_need_more_xp_for_a_point() -> void:
	var camp := TrainingCamp.new(_fighter({ "stats": { "boxing": 30, "takedowns": 55 } }), 1)
	assert_almost_eq(camp.xp_per_point("boxing"), 10.0 * exp(30.0 / 25.0), 0.001)
	assert_gt(camp.xp_per_point("takedowns"), camp.xp_per_point("boxing") * 2.5, "25 points more costs e (≈2.7) times the XP")


func test_growth_slows_right_down_near_the_fighters_potential() -> void:
	var low := TrainingCamp.new(_fighter({ "stats": { "boxing": 60 }, "potential": 60 }), 1)
	var high := TrainingCamp.new(_fighter({ "stats": { "boxing": 60 }, "potential": 90 }), 1)
	assert_gt(low.xp_per_point("boxing"), high.xp_per_point("boxing") * 3.0)


func test_gifts_raise_a_stats_ceiling() -> void:
	var camp := TrainingCamp.new(_fighter({ "gifts": ["freak_athlete", "heavy_hands"] }), 1)
	assert_eq(camp.ceiling("speed"), 85.0)
	assert_eq(camp.ceiling("power"), 85.0)
	assert_eq(camp.ceiling("boxing"), 75.0)


func test_a_played_session_is_worth_up_to_one_and_a_half_auto_ones() -> void:
	var library := _library_with("one_drill", "boxing_drill")
	var auto := TrainingCamp.new(_fighter(), 1, library).run_week("one_drill")
	var great := TrainingCamp.new(_fighter(), 1, library).run_week("one_drill", { 0: 1.5 })
	var awful := TrainingCamp.new(_fighter(), 1, library).run_week("one_drill", { 0: 0.1 })
	assert_almost_eq(great.gains.boxing / auto.gains.boxing, 1.5, 0.0001)
	assert_almost_eq(awful.gains.boxing / auto.gains.boxing, 0.8, 0.0001, "bad play still gets 80%")


func test_young_coachable_fast_learners_learn_faster_than_old_stubborn_ones() -> void:
	var kid := TrainingCamp.new(_fighter({ "age": 17, "personality": { "coachable": 100 }, "gifts": ["fast_learner"] }), 1)
	var vet := TrainingCamp.new(_fighter({ "age": 35, "personality": { "coachable": -100 } }), 1)
	var normal := TrainingCamp.new(_fighter(), 1)
	assert_almost_eq(normal.learning(), 1.0, 0.0001)
	assert_almost_eq(kid.learning(), 1.2 * 1.25 * 1.15, 0.0001)
	assert_almost_eq(vet.learning(), 0.6 * 0.75, 0.0001)


func test_tired_fighters_learn_less() -> void:
	var camp := TrainingCamp.new(_fighter(), 1)
	camp.fatigue = 40.0
	assert_eq(camp.fatigue_factor(), 1.0)
	camp.fatigue = 70.0
	assert_almost_eq(camp.fatigue_factor(), 0.75, 0.0001)
	camp.fatigue = 100.0
	assert_almost_eq(camp.fatigue_factor(), 0.5, 0.0001)


func test_rest_and_sundays_bring_fatigue_back_down() -> void:
	var library := _no_injuries()
	var camp := TrainingCamp.new(_fighter(), 3, library)
	var hard: Dictionary = camp.run_week("all_out")
	assert_gt(hard.fatigue_peak, 50.0, "a week with no rest wears a fighter down")
	assert_lt(hard.fatigue_end, hard.fatigue_peak, "Sunday takes some of it away")
	var taper: Dictionary = camp.run_week("taper")
	assert_lt(taper.fatigue_end, hard.fatigue_end, "a taper week brings them in fresh")
	var balanced: Dictionary = TrainingCamp.new(_fighter(), 3, library).run_week("balanced")
	assert_lt(balanced.fatigue_peak, hard.fatigue_peak)


func test_injury_risk_climbs_with_fatigue_and_falls_with_durability() -> void:
	var camp := TrainingCamp.new(_fighter(), 1)
	var sparring: Dictionary = TrainingLibrary.shared().session("hard_sparring")
	var fresh: float = camp.injury_chance(sparring)
	camp.fatigue = 60.0
	assert_almost_eq(camp.injury_chance(sparring), fresh * 5.0, 0.00001)
	var tough := TrainingCamp.new(_fighter({ "stats": { "durability": 90 } }), 1)
	assert_lt(tough.injury_chance(sparring), fresh)


func test_an_injured_fighter_rests_instead_of_training() -> void:
	var camp := TrainingCamp.new(_fighter(), 1, _no_injuries())
	camp.injured_days = 2
	var week: Dictionary = camp.run_week("balanced")
	assert_eq(week.slots[0].result, TrainingCamp.INJURED)
	assert_eq(week.slots[2].result, TrainingCamp.INJURED)
	assert_ne(week.slots[4].result, TrainingCamp.INJURED, "back on Wednesday")
	assert_eq(week.injured, 4)


func test_party_animals_skip_sessions_and_disciplined_fighters_never_do() -> void:
	var plans: Array[String] = ["balanced", "balanced", "balanced", "balanced"]
	var party := TrainingCamp.new(_fighter({ "personality": { "discipline": -100 } }), 5)
	var disciplined := TrainingCamp.new(_fighter({ "personality": { "discipline": 60 } }), 5)
	var skipped: Array[int] = [0, 0]
	for week: Dictionary in party.run_camp(plans):
		skipped[0] += week.skipped
	for week: Dictionary in disciplined.run_camp(plans):
		skipped[1] += week.skipped
	assert_gt(skipped[0], 0)
	assert_eq(skipped[1], 0)


func test_a_week_of_push_the_pace_adds_about_three_pace() -> void:
	var camp := TrainingCamp.new(_fighter({ "personality": { "discipline": 50 } }), 2, _no_injuries())
	var week: Dictionary = camp.run_week("push_the_pace")
	assert_between(camp.style.value(StyleLeanings.PACE), 2.5, 3.5)
	assert_almost_eq(week.leanings.pace, camp.style.value(StyleLeanings.PACE), 0.0001)


func test_wrestling_camps_push_a_fighter_towards_grappler() -> void:
	var library := _no_injuries()
	var camp := TrainingCamp.new(_fighter(), 2, library)
	var plans: Array[String] = ["wrestler", "wrestler", "wrestler", "wrestler"]
	camp.run_camp(plans)
	assert_gt(camp.style.value(StyleLeanings.BASE), 10.0)
	var older := TrainingCamp.new(_fighter({ "age": 31 }), 2, library)
	older.run_camp(plans)
	assert_lt(older.style.value(StyleLeanings.BASE), camp.style.value(StyleLeanings.BASE), "a style sets around 30")


func test_hard_sparring_wears_the_chin_down() -> void:
	var camp := TrainingCamp.new(_fighter(), 1, _library_with("one_spar", "hard_sparring"))
	var week: Dictionary = camp.run_week("one_spar")
	assert_almost_eq(camp.stat("chin"), 59.95, 0.0001)
	assert_almost_eq(week.chin_wear, 0.05, 0.0001)


func test_points_past_the_soft_cap_in_one_camp_count_half() -> void:
	var library := _no_injuries()
	_all_week(library, "boxing_week", "boxing_drill")
	var kid := { "age": 16, "stats": { "boxing": 20, "durability": 50, "recovery": 50 } }
	var one_camp := TrainingCamp.new(_fighter(kid), 4, library)
	var two_camps := TrainingCamp.new(_fighter(kid), 4, library)
	for camp: TrainingCamp in [one_camp, two_camps]:
		camp.run_week("boxing_week")
		camp.run_week("boxing_week")
	assert_gt(one_camp.stat("boxing"), 23.0, "two weeks of boxing put a beginner past the soft cap")
	two_camps.start_camp()
	var capped: Dictionary = one_camp.run_week("boxing_week")
	var fresh: Dictionary = two_camps.run_week("boxing_week")
	# A touch over half: growing slower keeps the next point a little cheaper.
	assert_between(capped.gains.boxing / fresh.gains.boxing, 0.5, 0.56)


func test_an_eight_week_camp_moves_a_young_wrestlers_main_stats_a_few_points() -> void:
	var young := _fighter({ "age": 17, "stats": { "takedowns": 30, "scrambles": 30, "clinch_control": 30, "boxing": 30 } })
	var camp := TrainingCamp.new(young, 11)
	var plans: Array[String] = ["wrestler", "wrestler", "wrestler", "wrestler", "wrestler", "wrestler", "wrestler", "taper"]
	camp.run_camp(plans)
	assert_between(camp.stat("takedowns") - 30.0, 1.0, 6.0)
	assert_lt(camp.stat("boxing") - 30.0, camp.stat("takedowns") - 30.0, "a wrestling camp trains wrestling most")


func test_the_trained_profile_still_fights() -> void:
	var roster := FighterLibrary.load_dir()
	var camp := TrainingCamp.new(roster.profile("wrestler"), 1)
	var plans: Array[String] = ["wrestler", "wrestler", "taper"]
	camp.run_camp(plans)
	var trained: Dictionary = camp.profile()
	trained.id = "wrestler_trained"
	roster.add(trained)
	assert_gt(float(trained.stats.takedowns), 70.0)
	var row: Dictionary = FightSummary.run(1, roster, ActionLibrary.load_dir(), "wrestler_trained", "kicker")
	assert_has(["red", "blue", "draw"], row.winner)


func test_fights_read_a_trained_stat_to_the_nearest_whole_point() -> void:
	var f := FighterState.from_profile({ "name": "Trained", "stats": { "takedowns": 70.8, "chin": 59.7, "boxing": 45.4 } })
	assert_eq(f.stat("takedowns"), 71)
	assert_eq(f.stat("chin"), 60)
	assert_eq(f.stat("boxing"), 45)
