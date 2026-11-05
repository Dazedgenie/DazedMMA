extends GutTest
## The gym's other fighters (sim/world/lads.gd, docs/03 §14.4, D444): the world's men who train at your gym, the first
## two walking in, the month's walk-ins and leavers, the room the members make, the sparring partner's share of his
## partner sessions, gym-mates never offered against him, the news, and the save.


func _career() -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 16
	p.potential = 80
	var gym := { "kind": "mma_gym", "culture": "family", "place": "unit", "name": "Test Gym", "owner_name": "Frank Doyle",
		"owner": "Owns it.", "dues": 40, "members": 16, "members_start": 16, "rent": Gym.rent_for(16, 40) }
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym, "country": "England", "hometown": "Leeds" })
	c.gym_money = 2000
	c.next_offers_week = 1000
	return c


func _lad(id: String, avg: float) -> Dictionary:
	return { "id": id, "name": "Lad %s" % id, "style": "boxer", "born": 18.0, "avg": avg, "record": "3-1-0", "pro": false,
		"country": "England", "since": 0 }


func test_the_first_two_lads_are_his_countrys_young_amateurs_and_local_pros_his_towns_first() -> void:
	var c: Career = _career()
	var lads: Array = c.gym_lads()
	assert_eq(lads.size(), Lads.MIN_LADS)
	var w: World = c.world()
	var town: int = 0
	for lad: Dictionary in lads:
		var m: Dictionary = w.man(String(lad.id))
		assert_false(m.is_empty(), "a real man from the world")
		assert_true(World.active(m))
		assert_true(String(m.tier) in Lads.TIERS, String(m.tier))
		assert_between(World.age_of(m, c.week), Lads.AGES[0], Lads.AGES[1])
		assert_eq(NameLibrary.shared().country_id_of(String(m.country)), w.country_id, "from his country")
		assert_eq(String(lad.record), World.record_text(m))
		if String(m.get("hometown", "")) == w.hometown:
			town += 1
	var pool: Array = Lads.candidates(w, { "lads": [], "former": [] }, c.week)
	var town_men: int = pool.filter(func(m: Dictionary) -> bool: return String(m.get("hometown", "")) == w.hometown).size()
	if town_men >= Lads.MIN_LADS:
		assert_eq(town, Lads.MIN_LADS, "his town's men first")
	assert_eq(c.gym_lads(), lads, "the same two")


func test_the_gym_has_room_for_one_lad_every_eight_members() -> void:
	assert_eq(Lads.room({ "members": 0 }), Lads.MIN_LADS)
	assert_eq(Lads.room({ "members": 24 }), 3)
	assert_eq(Lads.room({ "members": 400 }), Lads.MAX_LADS)


func test_each_month_lads_walk_in_while_theres_room_and_some_leave_for_good() -> void:
	var c: Career = _career()
	c.gym_lads()
	c.gym.members = 64  # Room for 8.
	var w: World = c.world()
	var news: Array = []
	for month in 36:
		var dice := RandomNumberGenerator.new()
		dice.seed = hash([month, "test"])
		news.append_array(Lads.month(w, c.gym, c.week, dice))
		assert_lte(Lads.lads(c.gym).size(), Lads.room(c.gym))
	var kinds: Array = news.map(func(e: Dictionary) -> String: return String(e.kind))
	assert_gt(kinds.count(Lads.WALKED_IN), 2, "lads walk in")
	assert_gt(kinds.count(Lads.LEFT), 0, "one leaves now and then")
	for id: String in c.gym.former:
		assert_false(Lads.at_gym(c.gym, id), "a man who left isn't back")
	var seen: Dictionary = {}
	for lad: Dictionary in Lads.lads(c.gym):
		assert_false(seen.has(lad.id), "each man once")
		seen[lad.id] = true


func test_a_man_who_retires_leaves_the_gym() -> void:
	var c: Career = _career()
	var lad: Dictionary = c.gym_lads()[0]
	c.world().man(String(lad.id)).retired = c.week
	var dice := RandomNumberGenerator.new()
	dice.seed = 7
	var news: Array = Lads.month(c.world(), c.gym, c.week, dice)
	assert_false(Lads.at_gym(c.gym, String(lad.id)))
	assert_true(Lads.used_to(c.gym, String(lad.id)))
	var gone: Array = news.filter(func(e: Dictionary) -> bool: return String(e.name) == String(lad.name))
	assert_eq(gone.size(), 1)
	assert_true(bool(gone[0].retired))
	assert_string_contains(Career.event_text(gone[0]), "retired")


func test_the_month_is_seeded() -> void:
	var a: Career = _career()
	var b: Career = _career()
	a.gym_lads()
	b.gym_lads()
	var da := RandomNumberGenerator.new()
	da.seed = 11
	var db := RandomNumberGenerator.new()
	db.seed = 11
	assert_eq(Lads.month(a.world(), a.gym, a.week, da), Lads.month(b.world(), b.gym, b.week, db))
	assert_eq(a.gym.lads, b.gym.lads)


func test_a_better_partner_speeds_his_partner_sessions_and_nobody_slows_them() -> void:
	var sparring := { "partner": true }
	assert_eq(Lads.partner_share({}, 50.0, sparring), 1.0, "no gym")
	assert_eq(Lads.partner_share({ "lads": [_lad("a", 70.0)] }, 50.0, { "partner": false }), 1.0, "no partner in a bag session")
	assert_almost_eq(Lads.partner_share({ "lads": [] }, 50.0, sparring), 1.0 - Lads.PARTNER_DOWN, 0.0001, "nobody to spar")
	assert_almost_eq(Lads.partner_share({ "lads": [_lad("a", 40.0), _lad("b", 60.0)] }, 50.0, sparring), 1.0 + Lads.PARTNER_UP,
		0.0001, "his best lad 10 better")
	assert_almost_eq(Lads.partner_share({ "lads": [_lad("a", 55.0)] }, 50.0, sparring), 1.0 + Lads.PARTNER_UP / 2.0, 0.0001)
	assert_almost_eq(Lads.partner_share({ "lads": [_lad("a", 30.0)] }, 50.0, sparring), 1.0 - Lads.PARTNER_DOWN, 0.0001, "all weaker")
	assert_eq(Lads.partner_share({ "lads": [_lad("a", 50.0)] }, 50.0, sparring), 1.0, "even")
	for id: String in ["hard_sparring", "light_sparring", "rolling", "wrestling_drill", "clinch_work", "shark_tank", "sprawl_drill"]:
		assert_true(bool(TrainingLibrary.shared().session(id).get("partner", false)), id)
	assert_false(bool(TrainingLibrary.shared().session("heavy_bag").get("partner", false)))


func test_a_camp_week_of_sparring_learns_more_with_a_better_lad_at_the_gym() -> void:
	var weak: Career = _career()
	var strong: Career = _career()
	weak.gym.lads = [_lad("a", 20.0)]
	strong.gym.lads = [_lad("a", 90.0)]
	weak.gym.former = []
	strong.gym.former = []
	var before: Dictionary = weak.trainee.stats.duplicate()
	var plan: Dictionary = { "schema": "week_plan@1", "id": "test", "instruction": null, "days": [] }
	for d in TrainingCamp.DAYS:
		plan.days.append(["rolling", "rest"])
	weak.trainee.run_plan(plan)
	strong.trainee.run_plan(plan)
	var gain := func(c: Career) -> float:
		var total: float = 0.0
		for id: String in before:
			total += float(c.trainee.stats[id]) - float(before[id])
		return total
	assert_gt(gain.call(strong), gain.call(weak))


func test_a_gym_mate_is_never_offered_against_him_and_a_former_one_is_flagged() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var mm: Matchmaker = c.matchmaker()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	c.gym.lads = []
	c.gym.former = []
	var id: String = ""
	var target: float = 0.0
	var style: String = ""
	for m: Dictionary in w.in_division(c.division_now(), c.week):  # A man the matchmaker would pick, at his level and style.
		target = w.average(m)
		style = String(m.style)
		if mm.pick_man(c, w, c.division_now(), target, style, [], rng) == String(m.id):
			id = String(m.id)
			break
	assert_ne(id, "", "somebody to fight")
	c.gym.lads = [Lads.snapshot(w, w.man(id), c.week)]
	for i in 30:
		rng.seed = i
		assert_ne(mm.pick_man(c, w, c.division_now(), target, style, [], rng), id, "not his gym-mate")
	c.gym.lads = []
	c.gym.former = [id]
	var o: Dictionary = mm._offer(c, w, id, "even", c.week + 6, {}, {}, 0)
	assert_true(bool(o.get("former_mate", false)))
	assert_string_contains(CareerHub.offer_text(c, o), "used to train")


func test_lad_news_reads_plainly() -> void:
	assert_eq(Lads.news_text({ "kind": Lads.WALKED_IN, "name": "Jake Moss", "gym": "Hill's Gym" }), "Jake Moss walked in to train at Hill's Gym")
	assert_string_contains(Lads.news_text({ "kind": Lads.LEFT, "name": "Jake Moss" }), "somewhere else")
	assert_eq(Lads.compare_text({ "avg": 60.0 }, 50.0), "Well ahead of him")
	assert_eq(Lads.compare_text({ "avg": 51.0 }, 50.0), "About even")
	assert_eq(Lads.compare_text({ "avg": 45.0 }, 50.0), "Still learning")


func test_the_lads_save_and_load() -> void:
	var c: Career = _career()
	c.gym_lads()
	c.gym.former = ["gone_man"]
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(Lads.lads(back.gym).size(), Lads.MIN_LADS)
	assert_eq(typeof(back.gym.lads[0].since), TYPE_INT)
	assert_eq(String(back.gym.lads[0].id), String(c.gym.lads[0].id))
	assert_true(Lads.used_to(back.gym, "gone_man"))


func test_a_gym_saved_before_lads_gets_its_first_two_and_trains_as_before_until_then() -> void:
	var c: Career = _career()
	var d: Dictionary = c.to_dict()
	(d.gym as Dictionary).erase("lads")
	(d.gym as Dictionary).erase("former")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(Lads.partner_share(back.gym, 50.0, { "partner": true }), 1.0, "no lads key: as before")
	assert_eq(back.gym_lads().size(), Lads.MIN_LADS, "they walk in")
