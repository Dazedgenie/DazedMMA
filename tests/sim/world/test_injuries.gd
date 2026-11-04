extends GutTest
## Named injuries (sim/world/injuries.gd, docs/03 §13.10, D406): each its own healing time and what it cuts, the camp
## picking one its kind of session causes, fights injuring him by what happened, the rare lasting dent, and hiding one
## from the doctor.


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func test_each_injury_hurts_its_own_thing_and_takes_its_own_time() -> void:
	assert_eq(Injuries.name_of("sprained_ankle"), "Sprained ankle")
	assert_eq(Injuries.area_of("sprained_ankle"), "legs")
	assert_lt(int(Injuries.effects("sprained_ankle").footwork), 0, "a sprained ankle cuts Footwork")
	assert_lt(int(Injuries.effects("broken_hand").power), 0, "a broken hand cuts Power")
	assert_string_contains(Injuries.effects_text("broken_hand"), "Power −8")
	assert_eq(Injuries.days_for("broken_hand", 0.0, false), 28)
	assert_eq(Injuries.days_for("broken_hand", 1.0, false), 56)
	assert_eq(Injuries.days_for("broken_hand", 0.0, true), ceili(28 * TrainingCamp.SLOW_HEALER), "a slow healer takes longer")
	assert_eq(Injuries.name_of("", "legs"), "Leg injury", "an old save's injury is named by where it is")


func test_a_session_picks_an_injury_its_kind_of_training_causes() -> void:
	var seen: Dictionary = {}
	for i in 50:
		var id: String = Injuries.pick_camp("conditioning", "legs", i / 50.0)
		assert_true("conditioning" in Injuries.get_injury(id).camp.kinds, "%s comes from conditioning" % id)
		seen[id] = true
	assert_gt(seen.size(), 1, "more than one can happen")
	assert_eq(Injuries.area_of(Injuries.pick_camp("no_such_kind", "head", 0.5)), "head", "failing any, one in its own area")


func test_a_camp_injury_is_named_and_cuts_his_stats_in_the_fight() -> void:
	var camp := TrainingCamp.new({ "id": "t", "name": "T", "age": 25, "stats": { "footwork": 60.0, "kicking": 50.0 } }, 1)
	camp.injured_days = 5
	camp.injury_area = "legs"
	camp.injury = "sprained_ankle"
	var night: Dictionary = camp.fight_night()
	assert_eq(String(night.injury), "sprained_ankle")
	assert_gt(float(night.hurt.legs), 0.0, "he starts the fight hurt there")
	var p: Dictionary = camp.fight_profile()
	assert_almost_eq(float(p.stats.footwork), 54.0, 0.01, "Footwork −6")
	assert_almost_eq(float(p.stats.kicking), 47.0, 0.01, "Kicking −3")
	camp.injury_area = "hands"
	camp.injury = "broken_hand"
	assert_true(camp.fight_night().hurt.is_empty(), "a hand starts nothing hurt: it only cuts stats")
	camp.injured_days = 60
	camp.injury_area = "head"
	camp.injury = "orbital_fracture"
	assert_almost_eq(float(camp.fight_night().hurt.head), TrainingCamp.HURT_MAX, 0.001, "however long it has to heal")


func test_a_fight_injures_him_by_what_happened() -> void:
	var rng := RandomNumberGenerator.new()
	var none: int = 0
	for i in 200:
		rng.seed = i
		if Injuries.from_fight({}, 0, [], rng).is_empty():
			none += 1
	assert_eq(none, 200, "unhurt and no punches thrown: nothing")
	var heads: int = 0
	var hands: int = 0
	var areas: Dictionary = {}
	for i in 1000:
		rng.seed = i
		var got: Dictionary = Injuries.from_fight({ "head": 1.0 }, 0, [], rng)
		if not got.is_empty():
			heads += 1
			areas[String(got.area)] = true
		rng.seed = i
		if not Injuries.from_fight({}, 100, [], rng).is_empty():
			hands += 1
	assert_between(heads, 280, 420, "about 35% when he finished badly hurt in the head")
	assert_eq(areas.keys(), ["head"])
	assert_between(hands, 100, 200, "100 punches landed: about a 15% chance of a hand injury")
	var brittle: int = 0
	for i in 1000:
		rng.seed = i
		if not Injuries.from_fight({}, 100, [Injuries.BRITTLE_FLAW], rng).is_empty():
			brittle += 1
	assert_gt(brittle, hands + 80, "twice as likely with Brittle hands")


func test_the_worst_injuries_rarely_leave_a_lasting_dent_and_most_never_do() -> void:
	assert_eq(Injuries.lasting("sprained_ankle", 0.0, 0.5), {}, "a sprain heals clean")
	var dent: Dictionary = Injuries.lasting("torn_knee_ligament", 0.0, 1.0)
	assert_eq(String(dent.stat), "footwork")
	assert_eq(int(dent.points), 4)
	assert_eq(Injuries.lasting("torn_knee_ligament", 0.99, 1.0), {}, "most of the time, none")


func test_a_fight_injury_goes_onto_his_record_and_keeps_him_out_alongside_the_suspension() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	assert_true(c.accept(String(c.offers[0].id)))
	var s: int = 0
	var paid_seed: int = c.career_seed
	while true:
		c.career_seed = paid_seed + s
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([c.career_seed, c.week, c.fights.size(), "fight injury"])
		if not Injuries.from_fight({ "legs": 1.0 }, 0, c.profile().get("flaws", []), rng).is_empty():
			break
		s += 1
	c.finish_fight({ "result": "loss", "method": "TKO", "round": 2, "hurt": { "head": 0.0, "body": 0.0, "legs": 1.0 } })
	var fight: Dictionary = c.fights[-1]
	assert_true(fight.get("injury") is Dictionary, "it's on his record")
	assert_eq(Injuries.area_of(String(fight.injury.id)), "legs")
	assert_eq(c.trainee.injury, String(fight.injury.id))
	assert_eq(c.trainee.injured_days, int(fight.injury.days) - Career.FIGHT_TO_MONDAY, "from fight night, like the suspension")
	assert_string_contains(Injuries.fight_text(fight.injury), Injuries.name_of(String(fight.injury.id)))


func test_the_chance_the_doctor_finds_out_grows_with_the_days_still_to_heal() -> void:
	assert_almost_eq(Injuries.found_chance(8), 0.35, 0.001)
	assert_gt(Injuries.found_chance(30), Injuries.found_chance(10))
	assert_eq(Injuries.found_chance(300), Injuries.HIDE_MAX, "never a sure thing")
