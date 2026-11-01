extends GutTest
## Weight divisions (sim/world/weight.gd, docs/03 §12.1, D351): he grows into his natural division by 21, fights at
## whatever his weight makes until his pro debut, then picks his natural division or one either side and stays there.


func _career(career_seed: int = 1) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "wrestling_family", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func test_the_division_is_the_lightest_he_can_make_with_a_normal_cut() -> void:
	assert_eq(Weight.ids(), ["bantamweight", "featherweight", "lightweight", "welterweight", "middleweight", "light_heavyweight"])
	assert_eq(Weight.division_for(60.0), "bantamweight", "52.8 kg after the cut")
	assert_eq(Weight.division_for(72.0), "featherweight", "63.4 kg: over bantam's 61.2")
	assert_eq(Weight.division_for(78.0), "lightweight", "68.6 kg makes 70.3")
	assert_eq(Weight.division_for(100.0), "light_heavyweight")
	assert_eq(Weight.division_for(125.0), "light_heavyweight", "no heavyweight until after launch (D56)")
	assert_eq(Weight.label("lightweight"), "Lightweight (70.3 kg, 155 lb)")


func test_taller_and_stockier_men_are_heavier() -> void:
	var short_lean: float = Weight.adult_kg({ "height_cm": 166, "build": "lean" })
	var tall_lean: float = Weight.adult_kg({ "height_cm": 186, "build": "lean" })
	var tall_stocky: float = Weight.adult_kg({ "height_cm": 186, "build": "stocky" })
	assert_lt(short_lean, tall_lean)
	assert_lt(tall_lean, tall_stocky)
	assert_eq(Weight.natural({ "height_cm": 166, "build": "lean" }), "bantamweight")
	assert_eq(Weight.natural({ "height_cm": 192, "build": "stocky" }), "light_heavyweight")
	assert_eq(Weight.adult_kg({ "height_cm": 166, "build": "lean", "adult_kg": 90.0 }), 90.0, "his own grown weight wins")


func test_he_grows_into_his_weight_by_21() -> void:
	assert_almost_eq(Weight.share(16.0), Weight.SHARE_AT_16, 0.0001)
	assert_almost_eq(Weight.share(18.5), (Weight.SHARE_AT_16 + 1.0) / 2.0, 0.0001)
	assert_eq(Weight.share(21.0), 1.0)
	assert_eq(Weight.share(30.0), 1.0, "and holds it")
	assert_almost_eq(Weight.share(13.0), Weight.SHARE_AT_16 - 3 * Weight.SHARE_PER_YEAR_UNDER_16, 0.0001)
	var c: Career = _career()
	assert_true(c.fighter.frame.has("adult_kg"), "a new career gives him his own grown weight")
	var at_16: float = c.weight_kg()
	for i in 52:
		c.run_week("time_off")
	assert_gt(c.weight_kg(), at_16, "a year older, heavier")
	assert_eq(c.division_now(), Weight.division_for(c.weight_kg()), "an amateur fights at what he weighs")


func test_at_his_pro_debut_he_picks_his_natural_division_or_one_either_side() -> void:
	assert_eq(Weight.debut_choices({ "adult_kg": 78.0 }), ["featherweight", "lightweight", "welterweight"])
	assert_eq(Weight.debut_choices({ "adult_kg": 60.0 }), ["bantamweight", "featherweight"], "nothing lighter than bantam")
	assert_eq(Weight.debut_choices({ "adult_kg": 110.0 }), ["middleweight", "light_heavyweight"])
	var c: Career = _career()
	c.fighter.frame.adult_kg = 78.0
	c.trainee.age_years = 18.0
	c.trainee.age = 18
	for i in Matchmaker.PRO_AFTER_FIGHTS:
		c.add_opponent({ "id": "opp_%d" % i, "name": "Man %d" % i })
		c.add_fight({ "result": "win", "opponent": "opp_%d" % i })
	assert_false(c.turn_pro("middleweight"), "two divisions up is too far")
	assert_false(c.pro)
	assert_true(c.turn_pro("welterweight"))
	assert_eq(c.division, "welterweight")
	assert_eq(c.division_now(), "welterweight", "and he stays there")
	assert_string_contains(CareerHub.weight_text(c), "since his pro debut")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.division, "welterweight", "saved")
	assert_eq(back.fighter.frame.adult_kg, 78.0)


func test_his_offers_are_men_of_his_division() -> void:
	var c: Career = _career(7)
	for i in 12:
		if not c.offers.is_empty():
			break
		c.run_week("time_off")
	assert_false(c.offers.is_empty())
	for o: Dictionary in c.offers:
		assert_eq(String(o.division), c.division_now())
		var man: Dictionary = c.world().man(String(o.profile.id))
		assert_eq(World.division_of(man, c.week), c.division_now(), "%s, one of the world's men, is in his division" % o.profile.name)
		assert_string_contains(CareerHub.offer_text(c, o), "bout")


func test_a_career_saved_before_divisions_still_loads() -> void:
	var c: Career = _career()
	var old: Dictionary = c.to_dict()
	old.fighter.frame.erase("adult_kg")
	old.erase("division")
	old.pro = true
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_false(back.fighter.frame.has("adult_kg"))
	assert_gt(back.weight_kg(), 40.0, "his weight comes from his height and build")
	assert_eq(back.division, back.natural_division(), "a pro without a division gets his natural one")
