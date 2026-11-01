extends GutTest
## The world's weeks (sim/world/world_weeks.gd, sim/world/result_model.gd, docs/03 §12.3, D353): the world's men fight
## each other about 3 times a year on the quick result model, get better young and slower old, turn pro, retire, and new
## men join each January.


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func _new_year(c: Career) -> Callable:
	return func(w: int) -> Dictionary: return c.date(0, w)


func _fights(events: Array) -> Array:
	return events.filter(func(r: Dictionary) -> bool: return String(r.get("kind", "fight")) == "fight")


func test_the_men_fight_each_other_about_three_times_a_year() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var events: Array = WorldWeeks.advance(w, 51, {}, _new_year(c))
	var fights: Array = _fights(events)
	var active: int = w.men.values().filter(func(m: Dictionary) -> bool: return World.active(m)).size()
	assert_between(2.0 * fights.size() / active, 2.0, 3.5, "fights a man a year")
	for r: Dictionary in fights.slice(0, 50):
		var a: Dictionary = w.man(String(r.a))
		var b: Dictionary = w.man(String(r.b))
		if not a.has("turned_pro") and not b.has("turned_pro"):
			assert_eq(bool(a.pro), bool(b.pro), "amateurs meet amateurs, pros pros")
		assert_true(String(r.winner) in ["a", "b", "draw"])
		assert_true(String(r.method) in ["ko", "submission", "decision", "draw"])
		assert_between(int(r.round), 1, 3)
	assert_eq(w.played, 51)


func test_the_same_world_plays_the_same_weeks() -> void:
	var a: Career = _career(5)
	var b: Career = _career(5)
	WorldWeeks.advance(a.world(), 30, {}, _new_year(a))
	WorldWeeks.advance(b.world(), 30, {}, _new_year(b))
	assert_eq(JSON.stringify(a.world().to_dict()), JSON.stringify(b.world().to_dict()))


func test_young_men_get_better_and_old_men_slow_down() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var young: Dictionary = {}
	for m: Dictionary in w.men.values():
		var age: float = World.age_of(m, 0)
		if age >= 17.0 and age < 19.0 and float(m.potential) > w.average(m) + 8.0:
			young = m
			break
	var before: float = w.average(young)
	for week in 52:
		young.lv = float(young.lv) + WorldWeeks.change_a_week(w, young, World.age_of(young, week))
	assert_gt(w.average(young), before + 1.0, "%s got better in a year" % young.name)
	var man := { "style": "boxer", "lv": 10.0, "potential": 80.0 }
	assert_gt(WorldWeeks.change_a_week(w, man, 20.0), WorldWeeks.change_a_week(w, man, 26.0), "growing fastest young")
	assert_eq(WorldWeeks.change_a_week(w, man, 30.0), 0.0, "his prime")
	assert_lt(WorldWeeks.change_a_week(w, man, 32.0), 0.0, "slowing down")
	assert_lt(WorldWeeks.change_a_week(w, man, 36.0), WorldWeeks.change_a_week(w, man, 32.0), "and faster later")


func test_good_amateurs_turn_pro_and_men_retire() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var events: Array = WorldWeeks.advance(w, 3 * 52, {}, _new_year(c))
	var pros: Array = events.filter(func(r: Dictionary) -> bool: return String(r.get("kind", "")) == "pro")
	var retired: Array = events.filter(func(r: Dictionary) -> bool: return String(r.get("kind", "")) == "retired")
	assert_gt(pros.size(), 10, "amateurs turned pro")
	assert_gt(retired.size(), 50, "men retired")
	var m: Dictionary = w.man(String(pros[0].id))
	assert_true(bool(m.pro))
	assert_true(m.has("amateur_record"), "his amateur record is kept")
	assert_ne(String(m.division), "", "a pro keeps his division")
	assert_between(World.age_of(m, int(pros[0].week)), WorldWeeks.PRO_FROM, WorldWeeks.PRO_LATE + 0.1)
	for r: Dictionary in retired:
		var gone: Dictionary = w.man(String(r.id))
		if not gone.is_empty():
			assert_false(World.active(gone))
			assert_false(gone.has("history"), "a retired man keeps only what the history needs")
			break


func test_each_january_new_men_join_and_divisions_stay_about_100() -> void:
	var c: Career = _career()
	var w: World = c.world()
	WorldWeeks.advance(w, 5 * 52, {}, _new_year(c))
	var joined: Array = w.men.values().filter(func(m: Dictionary) -> bool: return m.has("joined"))
	assert_gt(joined.size(), 0)
	var lads: Array = joined.filter(func(m: Dictionary) -> bool: return not bool(m.pro) and String(m.tier) == "amateur")
	assert_gt(lads.size(), 0, "new lads")
	for m: Dictionary in lads:
		assert_eq(String(m.country), "England", "from home")
	for division_id: String in Weight.ids():
		assert_between(w.in_division(division_id, w.played).size(), 70, 130, division_id)


func test_the_man_booked_to_fight_him_doesnt_fight_anyone_else() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var id: String = String(w.men.keys()[150])
	WorldWeeks.advance(w, 40, { id: true }, _new_year(c))
	for r: Dictionary in _fights(w.results):
		assert_ne(String(r.a), id)
		assert_ne(String(r.b), id)


func test_the_career_catches_the_world_up_and_saves_it() -> void:
	var c: Career = _career()
	c.world()
	for i in 6:
		c.run_week("time_off")
	assert_eq(c.world().played, c.week - 1, "the world's Saturdays up to last week")
	assert_false(c.world().results.is_empty())
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.world().played, c.world().played)
	assert_eq(JSON.stringify(back.world().to_dict(), "", true), JSON.stringify(c.world().to_dict(), "", true), "saved and loaded")
	var old: Dictionary = c.to_dict()
	for m: Dictionary in old.world.men:
		for key: String in ["lv", "potential", "next_week", "out_until", "retired", "history"]:
			m.erase(key)
	old.world.erase("played")
	old.world.erase("results")
	var older: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_eq(older.world().played, older.week - 1, "a world saved before D353 starts its weeks now")
	older.run_week("time_off")
	assert_eq(older.world().played, older.week - 1)


func test_the_hub_says_what_happened_around_his_division() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var men: Array[Dictionary] = w.in_division(c.division_now(), c.week)
	var a: Dictionary = men[0]
	var b: Dictionary = men[1]
	c.add_opponent(w.profile(String(a.id), c.week))
	c.add_fight({ "result": "win", "opponent": String(a.id) })
	w.results.append({ "kind": "fight", "week": c.week - 1, "division": c.division_now(), "a": String(a.id), "b": String(b.id),
		"winner": "b", "method": "ko", "round": 1, "chance": 0.8, "pro": bool(a.pro) })
	var text: String = CareerHub.news_text(c, 1)
	assert_string_contains(text, "AROUND THE %s" % Weight.name_of(c.division_now()).to_upper())
	assert_string_contains(text, "%s beat %s by knockout in round 1 (an upset)" % [b.name, a.name])
	assert_string_contains(text, "who you beat")


func test_the_result_model_favours_the_better_man_and_keeps_its_shares() -> void:
	assert_almost_eq(ResultModel.win_chance("boxer", 60.0, "wrestler", 55.0) + ResultModel.win_chance("wrestler", 55.0, "boxer", 60.0), 1.0, 0.0001)
	assert_gt(ResultModel.win_chance("boxer", 65.0, "boxer", 55.0), 0.8, "ten points better wins most")
	assert_almost_eq(ResultModel.win_chance("boxer", 55.0, "boxer", 55.0), 0.5, 0.0001, "the same style, the same level")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wins: int = 0
	var methods: Dictionary = {}
	for i in 400:
		var r: Dictionary = ResultModel.decide("muay_thai", 60.0, "bjj", 54.0, rng, 5)
		wins += 1 if String(r.winner) == "a" else 0
		methods[String(r.method)] = true
		assert_between(int(r.round), 1, 5)
	assert_gt(wins, 200)
	assert_true(methods.has("decision") and methods.has("ko"), "fights end different ways")


func test_the_shipped_table_agrees_with_the_engine_on_a_pair() -> void:
	var t: Dictionary = ResultModel.table()
	var keys: Array = (t.edges as Dictionary).keys()
	keys.sort_custom(func(x: String, y: String) -> bool: return absf(float(t.edges[x])) > absf(float(t.edges[y])))
	var pair: PackedStringArray = String(keys[0]).split(":")
	var jobs: Array[Dictionary] = []
	for n in 16:
		jobs.append({ "a": pair[0], "b": pair[1], "seed": 9000 + n, "avg_a": 55.0, "avg_b": 55.0, "a_red": n % 2 == 0 })
	var rows: Array = load("res://tools/matchups.gd")._play(jobs, 0, 1)
	var check: Dictionary = ResultModel.check(rows, t)
	assert_eq(int(check.inside), int(check.pairs), "the model's %s inside the engine's 95%% range (worst %s)" % [keys[0], check.worst])
