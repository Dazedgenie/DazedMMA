extends GutTest
## The world's promotions (sim/world/promotions.gd, docs/03 §12.4, D354): 2 organisations and 3 or 4 regional promotions
## a career, every pro signed by level, pros fighting on their promotion's cards, call-ups and cuts, and his pro offers
## on regional cards, mostly his home promotion's.


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func _new_year(c: Career) -> Callable:
	return func(w: int) -> Dictionary: return c.date(0, w)


func test_a_world_has_two_organisations_and_three_or_four_regional_promotions() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var orgs: Array = w.promotions.filter(func(p: Dictionary) -> bool: return int(p.rank) < Promotions.REGIONAL)
	assert_eq(orgs.map(func(p: Dictionary) -> int: return int(p.rank)), [Promotions.MAJOR, Promotions.SECOND])
	assert_between(Promotions.regionals(w).size(), 3, 4)
	assert_eq(String(Promotions.home(w).city), "Leeds", "one in his hometown")
	var names: Dictionary = {}
	var real: Array = (Promotions.data().real as Array).map(func(x: Variant) -> String: return String(x).to_lower())
	for p: Dictionary in w.promotions:
		assert_false(names.has(String(p.name)), "%s once" % p.name)
		names[String(p.name)] = true
		assert_false(String(p.name).to_lower() in real, "%s is made up" % p.name)
		assert_eq(String(p.short), Promotions.short_name(String(p.name)))
		if int(p.rank) == Promotions.REGIONAL:
			assert_eq(String(p.country), "england", "regional promotions are in his country")
	assert_gt(int(orgs[0].show), int(orgs[1].show), "the world organisation pays most")
	assert_gt(int(orgs[1].show), int(Promotions.regionals(w)[0].show))
	assert_eq(JSON.stringify(_career().world().promotions), JSON.stringify(w.promotions), "the same career makes the same promotions")


func test_every_pro_is_signed_by_level() -> void:
	var c: Career = _career()
	var w: World = c.world()
	for division_id: String in Weight.ids():
		var pros: Array = w.in_division(division_id, c.week).filter(func(m: Dictionary) -> bool: return bool(m.pro))
		pros.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return w.average(a) > w.average(b))
		assert_eq(int(Promotions.of(w, pros[0]).rank), Promotions.MAJOR, "%s's best man fights for the world organisation" % division_id)
		assert_eq(int(Promotions.of(w, pros[Promotions.MAJOR_MEN]).rank), Promotions.SECOND)
		assert_eq(int(Promotions.of(w, pros[-1]).rank), Promotions.REGIONAL)
	for m: Dictionary in w.men.values():
		if not bool(m.pro):
			assert_true(Promotions.of(w, m).is_empty(), "amateurs fight on local shows")


func test_pros_fight_on_their_promotions_cards() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var events: Array = WorldWeeks.advance(w, 40, {}, _new_year(c))
	var pro_fights: Array = events.filter(func(r: Dictionary) -> bool: return String(r.get("kind", "fight")) == "fight" and bool(r.pro))
	assert_gt(pro_fights.size(), 100)
	for r: Dictionary in pro_fights:
		var p: Dictionary = Promotions.by_id(w, String(r.promotion))
		assert_true(Promotions.has_card(p, int(r.week)), "%s runs a card in week %d" % [p.name, int(r.week)])
		assert_string_starts_with(String(r.card), String(p.short) + " ")
	var p0: Dictionary = w.promotions[0]
	assert_eq(Promotions.card_weeks(p0, int(p0.first_week), int(p0.first_week) + 3 * int(p0.every)).size(), 4, "a card every %d weeks" % int(p0.every))


func test_a_winning_run_gets_a_man_called_up_and_a_losing_run_let_go() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var man: Dictionary = {}
	for m: Dictionary in w.men.values():
		if bool(m.pro) and int(Promotions.of(w, m).rank) == Promotions.REGIONAL:
			man = m
			break
	man.history = [[1, "a", "w", "decision"], [2, "b", "w", "ko"], [3, "c", "w", "decision"]]
	Promotions.after_fight(w, man, 3)
	assert_eq(int(Promotions.of(w, man).rank), Promotions.SECOND, "three wins in a row: called up")
	assert_eq(String(w.results[-1].kind), "moved")
	assert_true(bool(w.results[-1].up))
	man.history.append([4, "d", "w", "ko"])
	Promotions.after_fight(w, man, 4)
	assert_eq(int(Promotions.of(w, man).rank), Promotions.SECOND, "his run starts again after a move")
	man.history.append_array([[5, "e", "l", "ko"], [6, "f", "l", "decision"], [7, "g", "l", "decision"]])
	Promotions.after_fight(w, man, 7)
	assert_eq(int(Promotions.of(w, man).rank), Promotions.REGIONAL, "three losses in a row: let go")


func test_his_pro_offers_are_on_regional_cards_mostly_at_home() -> void:
	var c: Career = _career()
	c.trainee.age_years = 20.0
	c.pro = true
	c.division = c.natural_division()
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	var at_home: int = 0
	var all: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 40:
		var o: Dictionary = Matchmaker.shared().make_offer(c, "", "even", rng, i)
		var p: Dictionary = Promotions.by_id(w, String(o.card.promotion))
		assert_eq(int(p.rank), Promotions.REGIONAL)
		assert_true(Promotions.has_card(p, int(o.week)), "the fight is on the night of its card")
		assert_gte(int(o.week) - c.week + 1, Matchmaker.CAMP_WEEKS_MIN + 1, "time for a camp")
		assert_eq(int(o.purse.show), int(p.show))
		assert_eq(int(Promotions.of(w, w.man(String(o.profile.id))).rank), Promotions.REGIONAL, "against a regional pro")
		all += 1
		at_home += 1 if String(p.id) == String(home.id) else 0
	assert_between(float(at_home) / all, 0.55, 0.92, "mostly his home promotion")


func test_a_world_saved_before_promotions_gets_them_when_loaded() -> void:
	var c: Career = _career()
	c.world()
	var old: Dictionary = c.to_dict()
	old.world.erase("promotions")
	for m: Dictionary in old.world.men:
		m.erase("promotion")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_eq(back.world().promotions.size(), c.world().promotions.size())
	var signed: int = back.world().men.values().filter(func(m: Dictionary) -> bool: return String(m.get("promotion", "")) != "").size()
	assert_gt(signed, 300, "his pros are signed")
	var again: Career = Career.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	assert_eq(JSON.stringify(again.world().promotions), JSON.stringify(back.world().promotions), "saved")


func test_the_hub_lists_the_promotions_with_their_next_cards() -> void:
	var c: Career = _career()
	var w: World = c.world()
	WorldWeeks.advance(w, 20, {}, _new_year(c))
	c.week = 21
	var text: String = CareerHub.promotions_text(c)
	for p: Dictionary in w.promotions:
		assert_string_contains(text, String(p.name))
	assert_string_contains(text, "World organisation")
	assert_string_contains(text, "Regional promotion")
	assert_string_contains(text, "Next: ")
	assert_string_contains(text, "Last lightweight card" if c.division_now() == "lightweight" else "Last ")
