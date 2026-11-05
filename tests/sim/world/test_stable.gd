extends GutTest
## Your stable (sim/world/stable.gd, docs/03 §14.5, D445): the places the members make, who you can sign and their
## chance of saying yes, signing off the gym's lads, what a focus trains, the gym's cut of their purses, unhappy men
## leaving, two of your stable never matched, the news, and the save.


func _career(members: int = 30) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 16
	p.potential = 80
	var gym := { "kind": "mma_gym", "culture": "family", "place": "unit", "name": "Test Gym", "owner_name": "Frank Doyle",
		"owner": "Owns it.", "dues": 40, "members": members, "members_start": members, "rent": Gym.rent_for(members, 40) }
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym, "country": "England", "hometown": "Leeds" })
	c.gym_money = 2000
	c.next_offers_week = 1000
	return c


## The first prospect who isn't one of the gym's lads, signed with a sure roll.
func _sign_local(c: Career, focus_id: String = Stable.DEFAULT_FOCUS) -> Dictionary:
	for m: Dictionary in c.stable_prospects():
		if not Lads.lads(c.gym).any(func(l: Dictionary) -> bool: return String(l.id) == String(m.id)):
			assert_eq(Stable.offer(c.world(), c.gym, m, c.week, 0.0, focus_id), "")
			return m
	return {}


func test_the_stable_has_a_place_every_ten_members_from_two_to_eight_his_among_them() -> void:
	assert_eq(Stable.places({ "members": 0 }), Stable.MIN_PLACES)
	assert_eq(Stable.places({ "members": 35 }), 3)
	assert_eq(Stable.places({ "members": 500 }), Stable.MAX_PLACES)
	assert_eq(Stable.free_places({ "members": 35, "stable": [] }), 2, "his lad takes one")
	assert_eq(Stable.free_places({ "members": 35, "stable": [{ "id": "a" }, { "id": "b" }] }), 0)


func test_the_prospects_are_the_gyms_lads_then_young_local_men_from_his_country() -> void:
	var c: Career = _career()
	var lads: Array = c.gym_lads()
	var w: World = c.world()
	var list: Array = c.stable_prospects()
	assert_gt(list.size(), lads.size())
	assert_lte(list.size(), lads.size() + Stable.PROSPECTS)
	for i in lads.size():
		assert_eq(String(list[i].id), String(lads[i].id), "the gym's lads first")
	for m: Dictionary in list.slice(lads.size()):
		assert_true(World.active(m))
		assert_true(String(m.tier) in Stable.TIERS, String(m.tier))
		assert_between(World.age_of(m, c.week), Stable.AGES[0], Stable.AGES[1])
		assert_eq(NameLibrary.shared().country_id_of(String(m.country)), w.country_id, "from his country")
		assert_false(Lads.at_gym(c.gym, String(m.id)))


func test_a_better_gym_and_a_weaker_man_make_a_yes_likelier() -> void:
	var gym := { "members": 30, "rooms": {}, "lads": [] }
	var amateur := { "id": "a", "tier": "amateur" }
	var regional := { "id": "r", "tier": "regional" }
	assert_gt(Stable.yes_chance(gym, amateur), Stable.yes_chance(gym, regional), "a weaker man says yes more")
	var built := { "members": 30, "rooms": { "ring": 2, "weights": 2 }, "lads": [] }
	assert_gt(Stable.yes_chance(built, regional), Stable.yes_chance(gym, regional), "better rooms help")
	var lad_gym := { "members": 30, "rooms": {}, "lads": [{ "id": "r" }] }
	assert_gt(Stable.yes_chance(lad_gym, regional), Stable.yes_chance(gym, regional), "a lad who trains here already")
	assert_between(Stable.yes_chance({ "rooms": { "ring": 99 } }, amateur), Stable.YES_RANGE[0], Stable.YES_RANGE[1])


func test_a_man_who_says_no_cant_be_asked_again_for_three_months() -> void:
	var c: Career = _career()
	var m: Dictionary = c.stable_prospects()[0]
	var w: World = c.world()
	var why: String = Stable.offer(w, c.gym, m, c.week, 0.999)
	assert_string_contains(why, "said no")
	assert_false(Stable.in_stable(c.gym, String(m.id)))
	assert_string_contains(Stable.cant_sign(c.gym, m, c.week + 1), "ask again in")
	assert_eq(Stable.cant_sign(c.gym, m, c.week + Stable.ASK_AGAIN_WEEKS), "")


func test_signing_a_lad_takes_him_off_the_lads_and_into_the_stable() -> void:
	var c: Career = _career()
	var lad: Dictionary = c.gym_lads()[0]
	var w: World = c.world()
	assert_eq(Stable.offer(w, c.gym, w.man(String(lad.id)), c.week, 0.0, "striking"), "")
	assert_true(Stable.in_stable(c.gym, String(lad.id)))
	assert_false(Lads.lads(c.gym).any(func(l: Dictionary) -> bool: return String(l.id) == String(lad.id)), "off the lads")
	assert_true(Lads.at_gym(c.gym, String(lad.id)), "still at the gym: never offered against him")
	assert_eq(String(Stable.entry(c.gym, String(lad.id)).focus), "striking")
	assert_string_contains(Stable.cant_sign(c.gym, w.man(String(lad.id)), c.week), "in your stable")


func test_once_the_places_are_full_nobody_else_can_sign() -> void:
	var c: Career = _career(20)  # Two places: his and one more.
	_sign_local(c)
	var next: Dictionary = c.stable_prospects()[0]
	assert_string_contains(Stable.cant_sign(c.gym, next, c.week), "No place")


func test_the_career_signs_with_its_own_seeded_roll_and_says_so_in_the_news() -> void:
	var c: Career = _career()
	var a: Career = _career()
	var id: String = String(c.stable_prospects()[0].id)
	a.stable_prospects()
	assert_eq(c.sign_fighter(id), a.sign_fighter(id), "the same roll for the same man and week")
	if Stable.in_stable(c.gym, id):
		var report: Dictionary = c.run_week()
		var texts: Array = report.events.map(func(e: Dictionary) -> String: return c.event_text(e))
		assert_true(texts.any(func(t: String) -> bool: return "signed to fight out of your gym" in t), str(texts))


func test_his_focus_puts_the_gyms_extra_growth_into_that_groups_stats() -> void:
	var m := { "id": "x" }
	var training := { "stats": Stable.focus_stats("striking"), "boost": 0.5 }
	Stable.train_week(m, 0.2, training)
	var striking: Array = Stable.focus_stats("striking")
	assert_gt(striking.size(), 0)
	assert_lt(striking.size(), StyleLibrary.stat_ids().size())
	for stat: String in m.gains:
		assert_true(stat in striking, "only his focus's stats: %s" % stat)
	assert_almost_eq(World.gained(m), 0.1, 0.001, "his average rises by growth × boost")
	assert_eq(Stable.focus_stats("all_round").size(), StyleLibrary.stat_ids().size(), "all-round trains every stat")
	Stable.train_week(m, -0.3, training)
	assert_almost_eq(World.gained(m), 0.1, 0.001, "a man going back loses nothing extra")


func test_a_signed_man_grows_faster_than_he_would_on_his_own() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign_local(c, "grappling")
	var alone: Career = _career()
	var before: float = c.world().average(m)
	for i in 26:
		c.end_week()
		alone.end_week()
	c.world()
	var twin: Dictionary = alone.world().man(String(m.id))
	var his: Dictionary = c.world().man(String(m.id))
	assert_gt(World.gained(his), 0.0, "the gym added to him")
	for stat: String in his.get("gains", {}):
		assert_true(stat in Stable.focus_stats("grappling"), stat)
	if World.active(his) and World.active(twin):
		assert_gt(c.world().average(his) - before, alone.world().average(twin) - before, "faster than on his own")


func test_the_gym_takes_its_cut_of_a_pro_purse_and_says_who_he_beat() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var pro: Dictionary = {}
	var other: Dictionary = {}
	for m: Dictionary in w.men.values():
		if World.active(m) and bool(m.get("pro", false)):
			if pro.is_empty():
				pro = m
			elif other.is_empty():
				other = m
	c.gym.stable = [Lads.snapshot(w, pro, c.week)]
	var paid: Dictionary = Stable.after_fights(w, c.gym, [{ "kind": "fight", "a": String(pro.id), "b": String(other.id),
		"winner": "a", "method": "ko" }])
	assert_eq(int(paid.cut), Gym.purse_cut(Stable.purse(w, pro, true)))
	assert_gt(int(paid.cut), 0)
	var line: String = Stable.news_text(paid.news[0])
	assert_string_contains(line, "beat %s by knockout" % String(other.name))
	assert_string_contains(line, "the gym's cut $%d" % int(paid.cut))
	assert_eq(Stable.purse(w, { "pro": false }, true), 0, "an amateur isn't paid")


func test_an_unhappy_man_is_warned_about_then_leaves_after_two_months() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign_local(c)
	var w: World = c.world()
	m.history = [[c.week - 3, "a", "l", "ko"], [c.week - 2, "b", "l", "decision"], [c.week - 1, "c", "l", "submission"]]
	var first: Array = Stable.month(w, c.gym, c.week, 100)
	assert_eq(first.size(), 1)
	assert_eq(String(first[0].kind), Stable.UNHAPPY)
	assert_string_contains(Stable.news_text(first[0]), "losses in a row")
	assert_true(Stable.in_stable(c.gym, String(m.id)), "warned first")
	var second: Array = Stable.month(w, c.gym, c.week + 4, -50)
	assert_eq(String(second[0].kind), Stable.LEFT)
	assert_string_contains(String(second[0].why), "behind on the rent")
	assert_false(Stable.in_stable(c.gym, String(m.id)))
	assert_true(Lads.used_to(c.gym, String(m.id)), "he can be offered against him now")


func test_a_happy_month_clears_the_worry_and_waiting_too_long_starts_one() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign_local(c)
	var w: World = c.world()
	m.history = [[c.week, "a", "w", "ko"]]
	assert_eq(Stable.month(w, c.gym, c.week + 4, 100), [])
	assert_eq(int(Stable.entry(c.gym, String(m.id)).unhappy), 0)
	var why: Array[String] = Stable.unhappy_reasons(m, Stable.entry(c.gym, String(m.id)), c.week + Stable.IDLE_WEEKS, 100)
	assert_eq(why, ["six months without a fight"] as Array[String])


func test_a_man_who_retires_leaves_the_stable() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign_local(c)
	m.retired = c.week
	var news: Array = Stable.month(c.world(), c.gym, c.week, 100)
	assert_eq(String(news[0].kind), Stable.LEFT)
	assert_string_contains(Stable.news_text(news[0]), "retired")
	assert_true(Stable.fighters(c.gym).is_empty())


func test_letting_a_man_go_and_changing_his_focus() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign_local(c)
	assert_true(c.set_stable_focus(String(m.id), "wrestling"))
	assert_eq(String(Stable.entry(c.gym, String(m.id)).focus), "wrestling")
	assert_false(c.set_stable_focus(String(m.id), "no_such_focus"))
	assert_false(c.release_fighter(String(m.id)).is_empty())
	assert_false(Stable.in_stable(c.gym, String(m.id)))
	assert_true(Lads.used_to(c.gym, String(m.id)))


func test_two_of_your_stable_are_never_matched_with_each_other() -> void:
	var c: Career = _career(80)
	var w: World = c.world()
	for i in 4:
		_sign_local(c)
	var ids: Dictionary = {}
	for e: Dictionary in Stable.fighters(c.gym):
		ids[String(e.id)] = true
	w.trained = Stable.trained(c.gym)
	var results: Array = WorldWeeks.advance(w, c.week + 104, {}, func(wk: int) -> Dictionary: return c.date(0, wk))
	for r: Dictionary in results:
		if String(r.get("kind", "")) == "fight":
			assert_false(ids.has(String(r.a)) and ids.has(String(r.b)), "two of your stable met")


func test_the_stable_saves_and_loads() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign_local(c, "fitness")
	c.gym.asked = { "someone": c.week }
	Stable.train_week(m, 0.2, Stable.trained(c.gym)[String(m.id)])
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var e: Dictionary = Stable.entry(back.gym, String(m.id))
	assert_eq(String(e.focus), "fitness")
	assert_eq(typeof(e.since), TYPE_INT)
	assert_eq(typeof(e.unhappy), TYPE_INT)
	assert_eq(typeof(back.gym.asked.someone), TYPE_INT)
	assert_almost_eq(World.gained(back.world().man(String(m.id))), World.gained(m), 0.001, "his gains kept")


func test_stable_news_reads_plainly() -> void:
	assert_eq(Stable.news_text({ "kind": Stable.SIGNED, "name": "Jake Moss" }), "Jake Moss signed to fight out of your gym")
	assert_eq(Stable.news_text({ "kind": Stable.FOUGHT, "name": "Jake Moss", "opponent": "Tom Reid", "result": "loss",
		"method": "decision", "cut": 0 }), "Jake Moss lost to Tom Reid by decision")
	assert_string_contains(Stable.news_text({ "kind": Stable.UNHAPPY, "name": "Jake Moss", "why": "x" }), "leave next month")
	assert_true(Career.STABLE_FOUGHT in Career.JUST_NEWS, "his stable's fights don't stop Advance")
	assert_false(Career.STABLE_UNHAPPY in Career.JUST_NEWS, "a warning does")
	for kind: String in [Career.STABLE_SIGNED, Career.STABLE_FOUGHT, Career.STABLE_UNHAPPY, Career.STABLE_LEFT]:
		assert_ne(CalendarIcon.colour_of(kind), Color("#adb5bd"), kind)
