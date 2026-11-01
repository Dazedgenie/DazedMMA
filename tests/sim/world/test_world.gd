extends GutTest
## The world's fighters (sim/world/world.gd, docs/03 §12.2, D352): about 100 named men a division in a pyramid of
## levels, local lads at home and the hotbeds at the top, his offers made from them, his fights on their records, and
## rematches after a while.


func _career(career_seed: int = 3, background: String = "street_kid") -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": background, "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func _until_offers(c: Career, weeks: int = 12) -> void:
	for i in weeks:
		if not c.offers.is_empty():
			return
		c.run_week("time_off")


func test_each_division_starts_with_100_men_in_a_pyramid() -> void:
	var w: World = _career().world()
	assert_eq(w.men.size(), World.PER_DIVISION * Weight.ids().size())
	for division_id: String in Weight.ids():
		assert_eq(w.in_division(division_id, 0).size(), World.PER_DIVISION, division_id)
	var tiers: Dictionary = {}
	for m: Dictionary in w.men.values():
		tiers[String(m.tier)] = int(tiers.get(String(m.tier), 0)) + 1
	for level: Dictionary in World.LEVELS:
		assert_eq(int(tiers.get(String(level.id), 0)), int(level.count) * Weight.ids().size(), String(level.id))
	var best: float = 0.0
	var amateur_best: float = 0.0
	for m: Dictionary in w.men.values():
		if bool(m.pro):
			best = maxf(best, w.average(m))
		else:
			amateur_best = maxf(amateur_best, w.average(m))
			assert_eq(int(m.record.win) + int(m.record.loss) + int(m.record.draw) <= ceili(maxf(0.0, World.age_of(m, 0) - 16.0) * 3.0 * 1.2) + 1, true, "an amateur's record fits his years")
	assert_gt(best, 70.0, "a few world-class men at the top")
	assert_lt(amateur_best, 51.0)


func test_the_same_career_makes_the_same_world_and_the_save_keeps_it() -> void:
	var a: Career = _career(5)
	var b: Career = _career(5)
	assert_eq(JSON.stringify(a.world().to_dict()), JSON.stringify(b.world().to_dict()))
	assert_ne(JSON.stringify(a.world().to_dict()), JSON.stringify(_career(6).world().to_dict()), "another career, other men")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_eq(JSON.stringify(back.world().to_dict()), JSON.stringify(a.world().to_dict()), "saved and loaded")
	var some: String = String(a.world().men.keys()[123])
	assert_eq(JSON.stringify(back.world().profile(some, 0)), JSON.stringify(a.world().profile(some, 0)), "the same fighter")
	var old: Dictionary = a.to_dict()
	old.erase("world")
	var older: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_eq(older.world().men.size(), a.world().men.size(), "a career saved before D352 makes its world")


func test_local_lads_at_home_and_the_hotbeds_at_the_top() -> void:
	var w: World = _career().world()
	var names: NameLibrary = NameLibrary.shared()
	var world_class: int = 0
	var english_at_top: int = 0
	var hotbeds_at_top: int = 0
	var leeds: int = 0
	for m: Dictionary in w.men.values():
		if String(m.tier) == "amateur":
			assert_eq(String(m.country), "England", "%s is a local lad" % m.name)
			if String(m.hometown) == "Leeds":
				leeds += 1
		if String(m.tier) == "world":
			world_class += 1
			if String(m.country) == "England":
				english_at_top += 1
			if names.hotbed(names.country_id_of(String(m.country))) >= 4.0:
				hotbeds_at_top += 1
	assert_gt(leeds, 40, "a lot of them from his hometown")
	assert_lt(english_at_top, world_class / 3, "few of the best from home")
	assert_gt(hotbeds_at_top, world_class / 4, "the hotbeds make the most")


func test_his_offers_are_the_worlds_men_and_his_fight_goes_on_their_record() -> void:
	var c: Career = _career()
	_until_offers(c)
	assert_false(c.offers.is_empty())
	var ids: Array = []
	for o: Dictionary in c.offers:
		var m: Dictionary = c.world().man(String(o.profile.id))
		assert_false(m.is_empty(), "%s is one of the world's men" % o.profile.name)
		assert_false(bool(m.pro), "an amateur meets amateurs")
		assert_between(World.age_of(m, c.week), 16.0, 18.0, "a teenager meets teenagers")
		assert_eq(String(o.about.record), World.record_text(m))
		assert_string_contains(CareerHub.offer_text(c, o), World.record_text(m))
		ids.append(String(o.profile.id))
	assert_eq(ids.size(), ({} if ids.is_empty() else _as_set(ids)).size(), "each a different man")
	var o: Dictionary = c.offers[0]
	var id: String = String(o.profile.id)
	var losses: int = int(c.world().man(id).record.loss)
	c.accept(String(o.id))
	c.finish_fight({ "result": "win", "method": "KO" })
	var man: Dictionary = c.world().man(id)
	assert_eq(int(man.record.loss), losses + 1, "his win is the man's loss")
	assert_false(World.can_rematch(man, c.week + 10), "no rematch straight away")
	assert_true(World.can_rematch(man, c.week + World.REMATCH_WEEKS))
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(int(back.world().man(id).record.loss), losses + 1, "kept in the save")


func test_a_close_fight_comes_round_again_sooner() -> void:
	assert_true(World.is_close("draw", "Decision"))
	assert_true(World.is_close("win", "Split decision"))
	assert_false(World.is_close("win", "Unanimous decision"))
	assert_false(World.is_close("loss", "KO"))
	var m := { "met_week": 10, "met_close": true }
	assert_false(World.can_rematch(m, 10 + World.CLOSE_REMATCH_WEEKS - 1))
	assert_true(World.can_rematch(m, 10 + World.CLOSE_REMATCH_WEEKS))
	assert_true(World.can_rematch({ "met_week": -1 }, 0), "never fought")


func test_a_pro_meets_pros_and_nobody_he_fought_lately() -> void:
	var c: Career = _career()
	c.trainee.age_years = 22.0
	c.trainee.age = 22
	c.pro = true
	c.division = c.division_now()
	for stat: String in c.trainee.stats:
		c.trainee.stats[stat] = 50.0
	_until_offers(c)
	assert_false(c.offers.is_empty())
	for o: Dictionary in c.offers:
		var m: Dictionary = c.world().man(String(o.profile.id))
		assert_true(bool(m.pro), "%s is a pro" % o.profile.name)
		assert_almost_eq(c.world().average(m), 50.0 + float(Matchmaker.DIFFICULTY_LEVELS[String(o.difficulty)]),
			float(Matchmaker.LEVEL_SPREAD) + Matchmaker.NEWCOMER_PAST, "as good as the offer says")
	var fought: Dictionary = c.offers[0]
	c.world().record_fight(String(fought.profile.id), "win", c.week, false)
	c.offers.clear()
	for i in 20:
		c.run_week("time_off")
		for o: Dictionary in c.offers:
			assert_ne(String(o.profile.id), String(fought.profile.id), "not again within a year")


func test_when_nobody_fits_a_new_man_joins_the_world() -> void:
	var c: Career = _career()
	c.trainee.age_years = 27.0
	c.trainee.age = 27
	c.pro = true
	c.division = c.division_now()
	for stat: String in c.trainee.stats:
		c.trainee.stats[stat] = 92.0
	var before: int = c.world().men.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var o: Dictionary = c.matchmaker().make_offer(c, "", "even", rng)
	assert_gt(c.world().men.size(), before, "better than anyone in the world: a new man")
	var m: Dictionary = c.world().man(String(o.profile.id))
	assert_eq(String(m.tier), "world")
	assert_true(bool(m.pro))
	assert_eq(World.division_of(m, c.week), c.division_now())


func _as_set(items: Array) -> Dictionary:
	var out: Dictionary = {}
	for x: Variant in items:
		out[x] = true
	return out
