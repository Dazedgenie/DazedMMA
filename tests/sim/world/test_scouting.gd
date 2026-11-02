extends GutTest
## Scouting and film study (sim/world/scouting.gd, docs/03 §13.1, D401): an opponent's grades as ranges until he's
## scouted, how well you know him, film study finding his habits, and spotting one in the fight.

const KICK := { "trigger": "own_jab_blocked", "action": "body_kick", "chance": 0.7, "within_ms": 1500 }
const OVERHAND := { "trigger": "opp_strike_misses", "action": "overhand", "chance": 0.5, "within_ms": 800 }


func _career() -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, 3, FighterLibrary.load_dir())


## A man to scout, with two habits, as an opponent of the career's.
func _man(c: Career, fights: int = 0) -> Dictionary:
	var p: Dictionary = { "id": "scout_test_man", "name": "Lee Marsh", "stats": { "boxing": 70.0, "kicking": 70.0 },
		"tells": [KICK.duplicate(), OVERHAND.duplicate()] }
	c.opponents[String(p.id)] = p
	if fights > 0:
		var m: Dictionary = c.world().man(c.world().men.keys()[0])
		m.record = { "win": fights, "loss": 0, "draw": 0 }
		p.id = String(m.id)
		c.opponents[String(p.id)] = p
	return p


func test_an_unscouted_grade_is_a_range_that_narrows_to_the_truth_once_he_is_known() -> void:
	var order: Array[String] = []
	for entry: Array in TrainingCamp.GRADES:
		order.push_front(String(entry[1]))
	var ranged: int = 0
	for s in 200:
		var value: float = 30.0 + float(s % 50)
		var truth: String = TrainingCamp.grade(value)
		var low_high: Array[String] = Scouting.grade_range(value, 0.0, s)
		assert_lte(order.find(low_high[0]), order.find(truth), "the truth is inside the range")
		assert_gte(order.find(low_high[1]), order.find(truth))
		if low_high[0] != low_high[1]:
			ranged += 1
		assert_eq(Scouting.grade_range(value, 1.0, s), [truth, truth] as Array[String], "known: his one true grade")
		assert_eq(Scouting.grade_range(value, 0.0, s), low_high, "the same man scouts the same")
	assert_gt(ranged, 150, "most unscouted grades are a range")
	assert_eq(Scouting.range_text(["B", "A−"] as Array[String]), "B–A−")
	assert_eq(Scouting.range_text(["C", "C"] as Array[String]), "C")


func test_you_know_a_man_better_for_his_fights_on_film_a_fight_with_him_and_film_study() -> void:
	var c: Career = _career()
	var stranger: Dictionary = _man(c)
	assert_eq(Scouting.knowledge(c, String(stranger.id)), 0.0, "nothing on film")
	var known: Dictionary = _man(c, 10)
	assert_almost_eq(Scouting.knowledge(c, String(known.id)), 10 * Scouting.FILM_PER_FIGHT, 0.001)
	_man(c, 100)
	assert_almost_eq(Scouting.knowledge(c, String(known.id)), Scouting.FILM_MAX, 0.001, "film only tells you so much")
	c.fights.append({ "opponent": String(known.id), "result": "win", "week": 0 })
	assert_almost_eq(Scouting.knowledge(c, String(known.id)), Scouting.FILM_MAX + Scouting.MET, 0.001, "you've fought him")
	Scouting.study(c, stranger, 2)
	assert_gt(Scouting.knowledge(c, String(stranger.id)), 0.2, "two film study sessions")
	Scouting.study(c, stranger, 10)
	assert_eq(Scouting.knowledge(c, String(stranger.id)), 1.0)


func test_film_study_finds_his_habits_one_at_a_time_and_a_sharper_mind_finds_them_sooner() -> void:
	var c: Career = _career()
	var p: Dictionary = _man(c)
	var found: Array[Dictionary] = []
	var sessions: int = 0
	while found.size() < 2 and sessions < 60:
		found.append_array(Scouting.study(c, p, 1))
		sessions += 1
		c.week += 1
	assert_eq(found.size(), 2, "both found in the end")
	assert_ne(Scouting.key(found[0]), Scouting.key(found[1]), "each once")
	assert_eq(Scouting.found(c, String(p.id)).size(), 2)
	assert_true(Scouting.unfound(c, p).is_empty())
	assert_eq(Scouting.study(c, p, 3), [] as Array[Dictionary], "nothing left to find")
	var plain: float = Scouting.find_chance(c, String(p.id))
	c.trainee.stats.fight_iq = 90.0
	assert_gt(Scouting.find_chance(c, String(p.id)), plain, "Fight IQ")
	var sharp: float = Scouting.find_chance(c, String(p.id))
	c.coach_specialty = Coach.TACTICIAN
	assert_almost_eq(Scouting.find_chance(c, String(p.id)), sharp + Scouting.FIND_TACTICIAN, 0.001, "a Tactician reads film")


func test_only_the_film_study_sessions_he_did_in_a_camp_study_the_man_he_is_booked_with() -> void:
	var c: Career = _career()
	var p: Dictionary = _man(c)
	var report := { "slots": [
		{ "session": "film_study", "result": TrainingCamp.DONE },
		{ "session": "film_study", "result": TrainingCamp.SKIPPED },
		{ "session": "boxing_drill", "result": TrainingCamp.DONE } ] }
	c.scout_week(report)
	assert_eq(Scouting.knowledge(c, String(p.id)), 0.0, "not booked: nobody to study")
	c.booked = { "opponent": String(p.id), "week": c.week + 4 }
	c.scout_week(report)
	var one: float = Scouting.knowledge(c, String(p.id))
	assert_almost_eq(one, Scouting.STUDY_GAIN * (1.0 + Scouting.STUDY_IQ * (c.trainee.stat("fight_iq") - 50.0) / 50.0), 0.001,
		"one session done")
	assert_true(report.has("scouted"), "what it found goes on the week's report")


func test_what_he_knows_of_a_man_is_saved_with_the_career() -> void:
	var c: Career = _career()
	var p: Dictionary = _man(c)
	Scouting.study(c, p, 1)
	Scouting.learn(c, String(p.id), [Scouting.key(KICK)])
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_almost_eq(Scouting.knowledge(back, String(p.id)), Scouting.knowledge(c, String(p.id)), 1e-9)
	assert_true(Scouting.found(back, String(p.id)).has(Scouting.key(KICK)))
	var old: Dictionary = c.to_dict()
	old.erase("scouting")
	assert_eq(Career.from_dict(JSON.parse_string(JSON.stringify(old))).scouting, {}, "a career saved before D401")


func test_a_habit_you_have_not_found_is_cued_once_you_have_seen_it_go_off_three_times() -> void:
	var watch := Scouting.Watch.new([Scouting.key(OVERHAND)])
	assert_true(watch.cues(OVERHAND), "found in camp")
	assert_false(watch.cues(KICK), "not found yet")
	var tick: int = 0
	for n in Scouting.SPOT_FIRES - 1:
		watch.set_off(KICK, tick)
		assert_eq(watch.started("body_kick", tick + 5), "")
		tick += 100
	watch.set_off(KICK, tick)
	assert_eq(watch.started("body_kick", tick + 1000), "", "a kick long after isn't the habit")
	watch.set_off(KICK, tick)
	assert_eq(watch.started("jab", tick + 2), "", "nor another move")
	assert_eq(watch.started("body_kick", tick + 3), Scouting.key(KICK), "the third time it's found")
	assert_true(watch.cues(KICK), "and cued from now on")
	assert_eq(watch.spotted, [Scouting.key(KICK)] as Array[String])
	assert_eq(watch.fires(Scouting.key(KICK)), Scouting.SPOT_FIRES)


func test_a_habit_reads_as_a_sentence() -> void:
	assert_eq(Scouting.tell_text(KICK), "When his jab is blocked, he throws a body kick (7 times in 10, within 1.5 s)")
	assert_string_contains(Scouting.tell_text(OVERHAND), "When he makes you miss, he throws an overhand")
	var c: Career = _career()
	var p: Dictionary = _man(c)
	var groups := { "boxing": "Striking", "kicking": "Striking" }
	var names: Array[String] = ["Striking"]
	var text: String = Scouting.report_text(c, p, groups, names)
	assert_string_contains(text, "Known: 0%")
	assert_string_contains(text, "Film study can find more")
	Scouting.learn(c, String(p.id), [Scouting.key(KICK)])
	assert_string_contains(Scouting.report_text(c, p, groups, names), "When his jab is blocked")
	Scouting.learn(c, String(p.id), [Scouting.key(OVERHAND)])
	assert_string_contains(Scouting.report_text(c, p, groups, names), "all his habits")
