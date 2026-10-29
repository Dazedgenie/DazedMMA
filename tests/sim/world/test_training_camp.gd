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


func test_a_forecast_shows_the_week_without_changing_the_camp() -> void:
	var library := _no_injuries()
	var camp := TrainingCamp.new(_fighter(), 1, library)
	var plan: Dictionary = library.plan("balanced")
	var forecast: Dictionary = camp.forecast(plan)
	assert_eq(camp.stat("boxing"), 40.0, "a forecast trains nobody")
	assert_eq(camp.fatigue, 0.0)
	var week: Dictionary = camp.run_plan(plan)
	assert_almost_eq(float(forecast.gains.boxing), float(week.gains.boxing), 0.0001, "with nobody hurt, the week does what the forecast said")
	assert_almost_eq(float(forecast.fatigue_peak), float(week.fatigue_peak), 0.0001)


func test_a_forecast_rolls_none_of_the_camps_dice() -> void:
	var plans: Array[String] = ["all_out", "all_out", "all_out", "all_out"]
	var plain := TrainingCamp.new(_fighter(), 9)
	var forecasting := TrainingCamp.new(_fighter(), 9)
	var plain_weeks: Array[Dictionary] = []
	var forecast_weeks: Array[Dictionary] = []
	for id in plans:
		plain_weeks.append(plain.run_week(id))
		forecasting.forecast(TrainingLibrary.shared().plan("all_out"))
		forecast_weeks.append(forecasting.run_week(id))
	assert_eq(forecast_weeks.map(func(w: Dictionary) -> Array: return w.injuries), plain_weeks.map(func(w: Dictionary) -> Array: return w.injuries))
	assert_eq(forecasting.profile().stats, plain.profile().stats)


func test_the_planners_own_week_trains_exactly_like_the_same_week_plan() -> void:
	var a := TrainingCamp.new(_fighter(), 3)
	var b := TrainingCamp.new(_fighter(), 3)
	var plan: Dictionary = TrainingLibrary.shared().plan("wrestler").duplicate(true)
	plan.id = "custom"
	a.run_week("wrestler")
	b.run_plan(plan)
	assert_eq(a.profile().stats, b.profile().stats)
	assert_eq(a.fatigue, b.fatigue)


func test_harder_weeks_carry_a_bigger_chance_of_an_injury() -> void:
	var library := TrainingLibrary.shared()
	var odds: Array[float] = []
	for id in ["taper", "balanced", "all_out"]:
		odds.append(float(TrainingCamp.new(_fighter(), 1).forecast(library.plan(id)).injury_odds))
	assert_lt(odds[0], odds[1])
	assert_lt(odds[1], odds[2])
	assert_between(odds[2], 0.05, 0.3, "about one All out camp in two or three has an injury over 8 weeks (docs/02 §3.5)")


func test_each_focus_week_trains_its_focus_most() -> void:
	var library := TrainingLibrary.shared()
	var flat := _fighter({ "stats": {} })
	var focus := { "speed": ["speed"], "cardio": ["cardio"], "power": ["power"], "jiu_jitsu": ["guard", "submissions", "top_control"],
		"defense": ["takedown_defense", "striking_defense", "submission_defense", "fight_iq"] }
	for id: String in focus:
		var gains: Dictionary = TrainingCamp.new(flat, 1).forecast(library.plan(id)).gains
		var top: Array = gains.keys()
		top.sort_custom(func(a: String, b: String) -> bool: return gains[a] > gains[b])
		assert_has(focus[id], top[0], "%s focus trains %s most" % [id, top[0]])


func test_grades_follow_the_docs_letter_scale() -> void:
	assert_eq(TrainingCamp.grade(85.0), "A+")
	assert_eq(TrainingCamp.grade(72.0), "A")
	assert_eq(TrainingCamp.grade(64.9), "B")
	assert_eq(TrainingCamp.grade(3.0), "F")
	assert_eq(TrainingCamp.freshness(10.0), "fresh")
	assert_eq(TrainingCamp.freshness(55.0), "worn down")


func test_a_camp_injury_says_where_it_hurts() -> void:
	var library := _no_injuries()
	var spar: Dictionary = library.session("hard_sparring").duplicate(true)
	spar.injury_risk = 0.05
	library.add_session(spar)
	_all_week(library, "spar_all_week", "hard_sparring")
	var camp := TrainingCamp.new(_fighter({ "stats": { "durability": 0 } }), 2, library)
	var week: Dictionary = camp.run_week("spar_all_week")
	assert_false(week.injuries.is_empty(), "a week of risky sparring hurts someone")
	assert_eq(week.injuries[0].area, "head", "sparring hurts the head")


func test_light_sessions_still_go_ahead_while_hurt_and_the_rest_become_rest() -> void:
	var library := _library_with("film_monday", "film_study")
	var camp := TrainingCamp.new(_fighter(), 1, library)
	camp.injured_days = 5
	camp.injury_area = "legs"
	var week: Dictionary = camp.run_week("film_monday")
	assert_eq(week.slots[0].result, TrainingCamp.DONE, "film study is light")
	assert_gt(float(week.gains.get("fight_iq", 0.0)), 0.0)
	var hard := TrainingCamp.new(_fighter(), 1, _library_with("bag_monday", "heavy_bag"))
	hard.injured_days = 5
	assert_eq(hard.run_week("bag_monday").slots[0].result, TrainingCamp.INJURED)


func test_rehab_heals_an_injury_faster_than_rest() -> void:
	var resting := TrainingCamp.new(_fighter(), 1, _library_with("rest_week", "rest"))
	var rehab := TrainingCamp.new(_fighter(), 1, _library_with("rehab_week", "rehab"))
	for camp: TrainingCamp in [resting, rehab]:
		camp.injured_days = 9
		camp.injury_area = "body"
	resting.run_week("rest_week")
	rehab.run_week("rehab_week")
	assert_eq(resting.injured_days, 2, "a week heals 7 days")
	assert_eq(rehab.injured_days, 1, "and a rehab session one more")
	rehab.run_week("rehab_week")
	assert_eq(rehab.injured_days, 0)
	assert_eq(rehab.injury_area, "", "healed")


func test_fight_night_fatigue_shrinks_the_gas_tank() -> void:
	assert_eq(TrainingCamp.tank_at(5.0), 1.0)
	assert_almost_eq(TrainingCamp.tank_at(30.0), 0.9, 0.0001, "Kyle: fatigue 30 is 90% of the tank")
	assert_almost_eq(TrainingCamp.tank_at(60.0), 0.75, 0.0001, "and 60 is 75%")
	assert_almost_eq(TrainingCamp.tank_at(100.0), 0.55, 0.0001, "worn right out: just over half")
	assert_gte(TrainingCamp.tank_at(1000.0), TrainingCamp.TANK_FLOOR)


func test_the_doctor_clears_a_small_injury_and_stops_a_bad_one() -> void:
	var camp := TrainingCamp.new(_fighter(), 1)
	assert_eq(camp.fight_night().doctor, TrainingCamp.FIT)
	assert_true(camp.fight_night().hurt.is_empty())
	camp.injured_days = 3
	camp.injury_area = "legs"
	var night: Dictionary = camp.fight_night()
	assert_eq(night.doctor, TrainingCamp.CLEARED_HURT)
	assert_almost_eq(float(night.hurt.legs), 0.09, 0.0001, "3 days to heal: 9% hurt")
	assert_almost_eq(float(night.worsen_chance), 0.08, 0.0001)
	camp.injured_days = TrainingCamp.DOCTOR_MAX_DAYS + 1
	assert_eq(camp.fight_night().doctor, TrainingCamp.NOT_CLEARED)


func test_the_fight_profile_carries_fight_night_into_the_fight() -> void:
	var camp := TrainingCamp.new(_fighter(), 1)
	camp.fatigue = 60.0
	camp.injured_days = 3
	camp.injury_area = "legs"
	var condition: Dictionary = camp.fight_profile().condition
	assert_almost_eq(float(condition.tank), 0.75, 0.0001)
	assert_almost_eq(float(condition.hurt.legs), 0.09, 0.0001)
	assert_false(camp.profile().has("condition"), "the trained profile itself stays as it was")


func test_fighting_hurt_sometimes_makes_it_worse_and_the_same_fight_always_says_the_same() -> void:
	var night := { "injured_days": 5, "injury_area": "body", "worsen_chance": 0.1 }
	var worse: int = 0
	for n in 400:
		var after: Dictionary = TrainingCamp.after_fight(night, n)
		if after.worse:
			worse += 1
			assert_between(int(after.days_out), 5 + TrainingCamp.WORSEN_DAYS_MIN, 5 + TrainingCamp.WORSEN_DAYS_MAX)
		else:
			assert_eq(after.days_out, 5)
	assert_between(worse, 20, 65, "about one in ten")
	assert_eq(TrainingCamp.after_fight(night, 7), TrainingCamp.after_fight(night, 7))
	assert_true(TrainingCamp.after_fight({ "injured_days": 0 }, 1).is_empty(), "not hurt, nothing to say")


func test_in_fight_week_the_fight_is_on_saturday_evening_with_no_sunday_to_recover() -> void:
	var plain := TrainingCamp.new(_fighter(), 1, _no_injuries())
	var fight := TrainingCamp.new(_fighter(), 1, _no_injuries())
	var normal: Dictionary = plain.run_plan(TrainingLibrary.shared().plan("all_out"))
	var last: Dictionary = fight.run_plan(TrainingLibrary.shared().plan("all_out"), {}, true)
	assert_eq(last.slots.size(), TrainingCamp.DAYS * TrainingCamp.SLOTS_PER_DAY - 1, "Saturday evening is the fight")
	assert_true(last.fight_week)
	assert_gt(fight.fatigue, plain.fatigue, "no night or Sunday after Saturday morning")
	assert_lt(TrainingCamp.tank_at(fight.fatigue), 1.0, "an All out fight week costs gas on the night")
	var tapered := TrainingCamp.new(_fighter(), 1, _no_injuries())
	tapered.run_camp(["all_out", "taper"] as Array[String], true)
	assert_eq(TrainingCamp.tank_at(tapered.fatigue), 1.0, "a Taper week brings the fighter in with a full tank")
