extends GutTest
## Ageing (sim/world/ageing.gd, docs/02 §3.8, D136): the body slows after 30 while skills
## keep growing, the body stops answering training around 28–29, and scouts see a range.


func _fighter(overrides: Dictionary = {}) -> Dictionary:
	var f := {
		"id": "trainee", "name": "Trainee", "template": null,
		"stats": { "speed": 70, "cardio": 70, "strength": 70, "power": 70, "boxing": 70, "fight_iq": 70 },
		"personality": { "ego": 0, "discipline": 0, "coachable": 0, "loyal": 0 },
		"style": { "pace": 0, "range": 0, "base": 0, "risk": 0 },
		"gifts": [], "flaws": [], "age": 25, "potential": 75,
	}
	f.merge(overrides, true)
	return f


func test_nothing_declines_before_thirty() -> void:
	for id: String in ["speed", "cardio", "recovery", "chin", "strength", "power", "boxing"]:
		assert_eq(Ageing.yearly_decline(id, 29.9), 0.0, id)


func test_speed_goes_about_one_percent_a_year_from_thirty_and_two_after_thirty_four() -> void:
	assert_almost_eq(Ageing.yearly_decline("speed", 30.0), 0.01, 0.0001)
	assert_almost_eq(Ageing.yearly_decline("cardio", 33.5), 0.01, 0.0001)
	assert_almost_eq(Ageing.yearly_decline("chin", 34.0), 0.02, 0.0001)


func test_strength_and_power_go_later_and_slower() -> void:
	assert_eq(Ageing.yearly_decline("strength", 32.0), 0.0)
	assert_almost_eq(Ageing.yearly_decline("power", 33.0), 0.005, 0.0001)
	assert_lt(Ageing.yearly_decline("power", 36.0), Ageing.yearly_decline("speed", 36.0))


func test_skills_and_fight_iq_never_age() -> void:
	var stats := { "boxing": 70.0, "fight_iq": 70.0, "speed": 70.0 }
	for week in 52:
		Ageing.age_a_week(stats, 40.0)
	assert_eq(stats.boxing, 70.0)
	assert_eq(stats.fight_iq, 70.0)
	assert_false(Ageing.ages("takedowns"))
	assert_true(Ageing.ages("speed"))


func test_a_year_at_thirty_one_takes_about_one_percent_off_speed() -> void:
	var stats := { "speed": 70.0 }
	var lost: float = 0.0
	for week in 52:
		lost += float(Ageing.age_a_week(stats, 31.0).get("speed", 0.0))
	assert_almost_eq(stats.speed, 70.0 * pow(1.0 - 0.01 / 52.0, 52.0), 0.001)
	assert_almost_eq(lost, 70.0 - stats.speed, 0.0001, "it reports what it took")


func test_each_week_of_camp_makes_the_fighter_a_week_older() -> void:
	var camp := TrainingCamp.new(_fighter({ "age": 34 }), 1)
	for week in 52:
		var report: Dictionary = camp.run_week("time_off")
		assert_true(report.aged.has("speed"), "a rest week still ages him")
	assert_eq(camp.age, 35)
	assert_lt(camp.stat("speed"), 70.0)
	assert_eq(camp.stat("boxing"), 70.0)
	assert_eq(camp.profile().age, 35, "the fight gets his new age")


func test_the_body_stops_answering_training_after_twenty_seven_but_skills_keep_learning() -> void:
	var young := TrainingCamp.new(_fighter({ "age": 25 }), 1)
	var thirty := TrainingCamp.new(_fighter({ "age": 31 }), 1)
	assert_almost_eq(young.learning("speed"), young.learning("boxing"), 0.0001)
	assert_lt(thirty.learning("speed"), thirty.learning("boxing") * 0.5)
	assert_almost_eq(thirty.learning("boxing"), 0.8, 0.0001)


func test_a_top_prospect_who_trains_well_peaks_physically_around_twenty_nine() -> void:
	var stats := {}
	for id: String in TrainingCamp.STAT_NAMES:
		stats[id] = 45
	var camp := TrainingCamp.new(_fighter({ "age": 18, "potential": 90, "stats": stats }), 3)
	var library := TrainingLibrary.shared()
	var physical := {}
	var plans: Array[String] = ["wrestler", "wrestler", "jiu_jitsu", "balanced"]
	while camp.age < 34:
		camp.start_camp()
		for w in 8:
			camp.run_plan(library.plan("taper" if w == 7 else plans[w % plans.size()]), {}, w == 7)
		for w in 9:
			camp.run_plan(library.plan("between_fights"))
		physical[camp.age] = (camp.stat("speed") + camp.stat("cardio") + camp.stat("strength") + camp.stat("recovery")) / 4.0
	assert_gt(physical[29], physical[25])
	assert_gt(physical[29], physical[33], "past the prime the body slows down")
	assert_between(camp.stat("takedowns"), 80.0, 95.0, "his main skills reach the top level")
	assert_gt(camp.stat("fight_iq"), 80.0)


func test_scouts_see_a_range_with_the_true_potential_inside() -> void:
	for scout_seed in 200:
		var scouted: Array[int] = Ageing.scouted_range(80.0, scout_seed)
		assert_true(scouted[0] <= 80 and 80 <= scouted[1], str(scouted))
		assert_eq(scouted[1] - scouted[0], 14)
	assert_eq(Ageing.scouted_range(80.0, 7), Ageing.scouted_range(80.0, 7), "the same fighter always scouts the same")

