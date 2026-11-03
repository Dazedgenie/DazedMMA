extends GutTest
## The film study minigame (sim/world/film_study.gd, docs/03 §13.4, D410): his tape, a clip where his habit goes off,
## marks judged against it, his habit named from three, the session's score, and a played session finding the habit for
## sure in a career.

var _roster: FighterLibrary
var _actions: ActionLibrary
var _kicker: Dictionary
var _study: FilmStudy


func before_all() -> void:
	_roster = FighterLibrary.load_dir()
	_actions = ActionLibrary.load_dir()
	_kicker = StyleLibrary.shared().generate("kicker", 1, 0, _roster)
	_study = FilmStudy.new(_kicker, {}, true, 50.0, 7, _roster, _actions)


func _fresh() -> FilmStudy:
	return FilmStudy.new(_kicker, {}, true, 50.0, 7, _roster, _actions)


func test_the_tape_is_a_minute_of_him_with_his_habit_going_off_at_least_twice() -> void:
	assert_gte(_study.fires.size(), FilmStudy.MIN_FIRES)
	assert_almost_eq(_study.length(), FilmStudy.CLIP_SECONDS / FilmStudy.SPEED, 0.5, "a minute on screen (D38)")
	for f: int in _study.fires:
		assert_between(f, _study.start, _study.end, "every fire is inside the clip")
		assert_true(_study.any_fires.has(f))


func test_the_same_seed_films_the_same_tape() -> void:
	var again: FilmStudy = _fresh()
	assert_eq(again.fires, _study.fires)
	assert_eq([again.start, again.end, again.stand_in, again.fight_seed], [_study.start, _study.end, _study.stand_in, _study.fight_seed])


func test_the_screen_plays_the_same_fight_up_to_the_clip() -> void:
	var sim: FightSim = _study.make_sim(_roster, _actions)
	var started: Array[int] = []
	sim.event_emitted.connect(func(e: FightEvent) -> void:
		if e.actor == 0 and e.type == FightEvent.ACTION_PHASE and String(e.data.get("phase", "")) == "telegraph":
			started.append(e.tick))
	while sim.now <= _study.end and not sim.is_over():
		sim.tick()
	for f: int in _study.fires:
		assert_true(started.has(f), "his habit's move starts on the tick the tape found it")


func test_a_mark_on_each_fire_catches_it_and_one_on_nothing_costs() -> void:
	var s: FilmStudy = _fresh()
	for f: int in s.fires:
		assert_eq(String(s.press(f + 2).result), "hit")
	assert_eq(s.caught(), s.fires.size())
	assert_almost_eq(s.mark_score(), 1.0, 0.001)
	var empty: int = s.start
	while s.any_fires.any(func(f: int) -> bool: return absi(f - empty) < 40):
		empty += 10
	assert_eq(String(s.press(empty).result), "stray")
	assert_almost_eq(s.mark_score(), 1.0 - FilmStudy.STRAY_COST / s.fires.size(), 0.001)
	assert_eq(String(s.press(s.fires[0]).result) != "hit", true, "a fire counts once")


func test_naming_his_habit_right_scores_the_session_and_finds_it() -> void:
	var s: FilmStudy = _fresh()
	assert_eq(s.choices.size(), FilmStudy.CHOICES)
	var his: Array[String] = []
	for t: Variant in _kicker.tells:
		his.append(Scouting.key(t))
	var right: int = -1
	for i in s.choices.size():
		if Scouting.key(s.choices[i]) == Scouting.key(s.habit):
			right = i
		else:
			assert_false(his.has(Scouting.key(s.choices[i])), "the other two aren't his")
	assert_gte(right, 0, "his habit is one of the three")
	for f: int in s.fires:
		s.press(f)
	assert_true(s.name_it(right))
	assert_almost_eq(s.quality(), TrainingCamp.PLAYED_MAX, 0.001, "every fire and the name: the best session")
	assert_eq(s.found_key(), Scouting.key(s.habit))
	var wrong: FilmStudy = _fresh()
	assert_false(wrong.name_it((right + 1) % FilmStudy.CHOICES))
	assert_eq(wrong.found_key(), "")
	assert_almost_eq(wrong.quality(), TrainingCamp.PLAYED_MIN, 0.001, "nothing marked, named wrong")


func test_a_sharper_mind_gets_a_wider_window() -> void:
	var sharp: FilmStudy = _fresh()
	sharp.fight_iq = 100.0
	var dull: FilmStudy = _fresh()
	dull.fight_iq = 0.0
	assert_gt(sharp.window()[1], _study.window()[1])
	assert_lt(dull.window()[1], _study.window()[1])


func test_a_man_of_a_style_trains_fight_iq_but_finds_nothing() -> void:
	var man: Dictionary = FilmStudy.sample_man("wrestler", 3, _roster)
	assert_eq(String(man.style_id), "wrestler")
	assert_false((man.tells as Array).is_empty())
	var s := FilmStudy.new(man, {}, false, 50.0, 3, _roster, _actions)
	for i in s.choices.size():
		if Scouting.key(s.choices[i]) == Scouting.key(s.habit):
			s.name_it(i)
	assert_true(s.named_right())
	assert_eq(s.found_key(), "", "nothing of his to find")
	assert_gt(s.quality(), TrainingCamp.PLAYED_MIN)
	assert_true(StyleLibrary.shared().has(String(FilmStudy.sample_man("", 5, _roster).style_id)), "any style, in a quick camp")


func test_a_played_session_that_named_his_habit_finds_it_for_sure() -> void:
	var c: Career = Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, 3, _roster)
	var him: Dictionary = _kicker.duplicate(true)
	him.id = "film_test_man"
	c.opponents[String(him.id)] = him
	c.booked = { "opponent": String(him.id), "week": c.week + 4, "camp_weeks": 5 }
	var target: Dictionary = him.tells[1]
	var report := { "slots": [{ "day": 0, "slot": 1, "session": Scouting.FILM_STUDY, "result": TrainingCamp.DONE }],
		"film": { 1: Scouting.key(target) } }
	var found: Array[Dictionary] = c.scout_week(report)
	assert_eq(found.map(func(t: Dictionary) -> String: return Scouting.key(t)), [Scouting.key(target)])
	assert_true(Scouting.found(c, String(him.id)).has(Scouting.key(target)))
	assert_almost_eq(float(c.scouting[String(him.id)].known), Scouting.study_gain(c), 0.001, "and studied him as a session does")
