extends GutTest
## The head coach (sim/world/coach.gd, docs/03 §10.6, D311): his background and specialty, what the specialty does to
## training and to calls, and the coach in a career and its save.


func _fighter() -> Dictionary:
	return {
		"id": "trainee", "name": "Trainee", "template": null,
		"stats": { "boxing": 40, "takedowns": 40, "durability": 50, "recovery": 50, "chin": 60 },
		"personality": { "ego": 0, "discipline": -100, "coachable": 0, "loyal": 0 },
		"style": { "pace": 0, "range": 0, "base": 0, "risk": 0 },
		"gifts": [], "flaws": [], "age": 25, "potential": 75,
	}


func _camp(specialty: String) -> TrainingCamp:
	var camp := TrainingCamp.new(_fighter(), 1)
	camp.coach_specialty = specialty
	return camp


func test_there_are_five_specialties_and_five_backgrounds_each_with_words() -> void:
	assert_eq(Coach.specialty_ids(), [Coach.STRIKING, Coach.WRESTLING, Coach.BJJ, Coach.MOTIVATOR, Coach.TACTICIAN])
	for id: String in Coach.specialty_ids():
		assert_ne(Coach.specialty_name(id), "", id)
		assert_ne(Coach.specialty_does(id), "", id)
	assert_eq(Coach.backgrounds().size(), 5)
	for id: String in Coach.backgrounds():
		assert_ne(Coach.background_name(id), "", id)
		assert_ne(Coach.background_about(id), "", id)


func test_a_skill_specialty_speeds_up_only_its_own_group() -> void:
	var none: TrainingCamp = _camp("")
	var striking: TrainingCamp = _camp(Coach.STRIKING)
	assert_almost_eq(striking.learning("boxing"), none.learning("boxing") * Coach.GROUP_XP, 0.0001, "boxing is striking")
	assert_almost_eq(striking.learning("takedowns"), none.learning("takedowns"), 0.0001, "takedowns aren't")
	assert_almost_eq(_camp(Coach.WRESTLING).learning("takedowns"), none.learning("takedowns") * Coach.GROUP_XP, 0.0001)
	assert_almost_eq(_camp(Coach.BJJ).learning("submissions"), none.learning("submissions") * Coach.GROUP_XP, 0.0001)
	assert_almost_eq(_camp(Coach.BJJ).learning("boxing"), none.learning("boxing"), 0.0001)


func test_a_striking_coach_gets_more_out_of_the_same_week() -> void:
	var none: TrainingCamp = _camp("")
	var striking: TrainingCamp = _camp(Coach.STRIKING)
	none.run_week("balanced")
	striking.run_week("balanced")
	assert_gt(striking.stat("boxing"), none.stat("boxing"))


func test_a_motivator_tires_him_less_and_keeps_a_party_animal_in_the_gym() -> void:
	var none: TrainingCamp = _camp("")
	var motivator: TrainingCamp = _camp(Coach.MOTIVATOR)
	assert_almost_eq(motivator.skip_chance(), none.skip_chance() * Coach.MOTIVATOR_SKIPS, 0.0001)
	var plan: Dictionary = TrainingLibrary.shared().plan("all_out")
	assert_lt(float(motivator.forecast(plan).fatigue_peak), float(none.forecast(plan).fatigue_peak))


func test_a_tactician_sends_him_out_with_calls_that_reach_him_sooner() -> void:
	assert_false(_camp("").fight_profile().condition.has("call_delay"), "no change without a Tactician")
	var p: Dictionary = _camp(Coach.TACTICIAN).fight_profile()
	assert_eq(float(p.condition.call_delay), Coach.TACTICIAN_DELAY)
	var f: FighterState = FighterState.from_profile(FighterLibrary.load_dir().profile("boxer").merged({ "condition": p.condition }, true))
	assert_eq(f.call_delay, Coach.TACTICIAN_DELAY)


func test_the_coach_comes_back_from_a_save_and_trains_the_same() -> void:
	var c: Career = Career.start({ "coach": "Sam Reed", "coach_background": "boxing_trainer", "coach_specialty": Coach.STRIKING,
		"name": "Danny Hill", "nickname": "", "hometown": "Leeds", "country": "England", "background": "boxing_gym_kid",
		"stance": "orthodox" }, 3, FighterLibrary.load_dir())
	assert_eq(c.coach_background, "boxing_trainer")
	assert_eq(c.trainee.coach_specialty, Coach.STRIKING)
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.coach_name, "Sam Reed")
	assert_eq(back.coach_background, "boxing_trainer")
	assert_eq(back.coach_specialty, Coach.STRIKING)
	assert_eq(back.trainee.coach_specialty, Coach.STRIKING)


func test_a_career_saved_before_the_coach_had_a_specialty_still_loads() -> void:
	var c: Career = Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "nickname": "", "hometown": "Leeds",
		"country": "England", "background": "boxing_gym_kid", "stance": "orthodox" }, 3, FighterLibrary.load_dir())
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	saved.coach = { "name": "Sam Reed" }
	var back: Career = Career.from_dict(saved)
	assert_not_null(back)
	assert_eq(back.coach_specialty, "")
	assert_eq(CareerHub.coach_text(back), "Sam Reed")
