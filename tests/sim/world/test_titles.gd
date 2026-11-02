extends GutTest
## The titles (sim/world/titles.gd, docs/03 §12.6, D356): a belt in every promotion's division, champions above the
## rankings, 5-round title fights about twice a year against the best ranked man who's free, belts stripped after a year
## without a defence, champions called up after one defence, and his own title fights.


func _career(career_seed: int = 3) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func _new_year(c: Career) -> Callable:
	return func(w: int) -> Dictionary: return c.date(0, w)


func _pro(c: Career) -> void:
	c.trainee.age_years = 21.0
	c.pro = true
	c.division = c.natural_division()


func test_day_one_every_promotion_has_its_best_man_as_champion() -> void:
	var c: Career = _career()
	var w: World = c.world()
	for p: Dictionary in w.promotions:
		for division_id: String in Weight.ids():
			var men: Array = Rankings._men_of(w, String(p.id), division_id)
			var champ: String = Titles.champion(w, String(p.id), division_id)
			if men.is_empty():
				assert_eq(champ, "")
				continue
			assert_ne(champ, "", "%s %s has a champion" % [p.short, division_id])
			for m: Dictionary in men:
				assert_gte(w.average(w.man(champ)), w.average(m), "the best man holds it")
			assert_false(Rankings.table(w, String(p.id), division_id).has(champ), "the champion sits above the rankings")
			assert_eq(Rankings.rank_of(w, champ), 0)
			assert_eq(Titles.held_by(w, champ), Rankings.key(String(p.id), division_id))


func test_belts_are_fought_for_on_the_cards_about_twice_a_year() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var events: Array = WorldWeeks.advance(w, 103, {}, _new_year(c))
	var title_fights: Array = events.filter(func(r: Dictionary) -> bool: return r.has("title"))
	var per_belt: float = float(title_fights.size()) / 2.0 / w.titles.size()
	assert_between(per_belt, 1.5, 3.5, "title fights a belt a year")
	var last: Dictionary = {}
	for r: Dictionary in title_fights:
		var p: Dictionary = Promotions.by_id(w, String(r.title).get_slice(":", 0))
		assert_true(Promotions.has_card(p, int(r.week)), "on its promotion's card")
		assert_between(int(r.round), 1, Titles.ROUNDS)
		if last.has(r.title) and String(r.title_how) == "defended":
			assert_gte(int(r.week) - int(last[r.title]), Titles.DEFENCE_WEEKS, "a defence at most every %d weeks" % Titles.DEFENCE_WEEKS)
		last[r.title] = int(r.week)
	assert_gt(title_fights.filter(func(r: Dictionary) -> bool: return String(r.title_how) == "won").size(), 10, "belts change hands")
	for k: String in w.titles:
		var champ: String = String(w.titles[k].champion)
		if champ != "":
			assert_true(World.active(w.man(champ)))
			assert_eq(String(w.man(champ).promotion), k.get_slice(":", 0), "a champion fights for his promotion")


func test_a_champion_a_year_without_a_defence_is_stripped_and_a_retired_one_leaves_it_vacant() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var p: Dictionary = w.promotions[0]
	var week: int = Promotions.card_weeks(p, 1, 20)[0]
	var k: String = Rankings.key(String(p.id), "lightweight")
	var champ: String = String(w.titles[k].champion)
	w.titles[k].last = week - Titles.STRIP_WEEKS
	var rng := RandomNumberGenerator.new()
	Titles.play_week(w, week, { champ: true }, rng)
	assert_ne(String(w.titles[k].champion), champ, "stripped")
	var said: Array = w.results.filter(func(r: Dictionary) -> bool: return String(r.get("kind", "")) == "title" and String(r.id) == champ)
	assert_eq(String(said[0].how), "stripped")
	assert_eq(String(w.titles[k].past[-1][0]), champ, "his reign is kept")
	var k2: String = Rankings.key(String(p.id), "welterweight")
	var champ2: String = String(w.titles[k2].champion)
	w.man(champ2).retired = week
	Titles.play_week(w, week, {}, rng)
	assert_ne(String(w.titles[k2].champion), champ2, "a retired champion's belt goes")


func test_a_regional_champion_is_called_up_after_one_defence() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	var week: int = Promotions.card_weeks(home, 1, 20)[0]
	var k: String = Rankings.key(String(home.id), "lightweight")
	var champ: String = String(w.titles[k].champion)
	w.titles[k].defences = Titles.CALL_UP_DEFENCES
	w.titles[k].last = week - 1
	for m: Dictionary in Rankings._men_of(w, "org_1", "lightweight").slice(Promotions.SECOND_MEN):
		Promotions.sign_to(w, m, Promotions.REGIONAL)  # Room in the international organisation.
	Titles.play_week(w, week, {}, RandomNumberGenerator.new())
	assert_eq(int(Promotions.of(w, w.man(champ)).rank), Promotions.SECOND, "called up")
	assert_ne(String(w.titles[k].champion), champ, "his belt goes vacant")


func test_at_number_one_or_two_he_is_offered_the_title_fight_at_double_pay() -> void:
	var c: Career = _career()
	_pro(c)
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	var k: String = Rankings.key(String(home.id), c.division)
	w.him = { "id": Career.FIGHTER_ID, "name": "Danny Hill", "pro": true, "promotion": String(home.id), "division": c.division,
		"points": [[c.week, 60.0, Promotions.REGIONAL, 1, "w", "ko", ""]] }
	Rankings.update(w, c.week, false)
	assert_eq(Rankings.rank_of(w, Career.FIGHTER_ID), 1)
	w.titles[k].last = c.week - Titles.DEFENCE_WEEKS
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var offers: Array = c.matchmaker().make_offers(c, rng)
	var title: Dictionary = offers[0]
	assert_eq(String(title.get("title", "")), k)
	assert_eq(String(title.profile.id), String(w.titles[k].champion), "against the champion")
	assert_eq(int(title.purse.show), int(Matchmaker.purse_for(c, home).show) * Titles.TITLE_PAY, "double pay")
	assert_true(Promotions.has_card(home, int(title.week)))
	assert_string_contains(CareerHub.offer_text(c, title), "Title shot")
	assert_gt(offers.size(), 1, "other offers too")
	w.him.points = [[c.week, 1.0, Promotions.REGIONAL, 0, "w", "decision", ""]]
	Rankings.update(w, c.week, false)
	assert_gt(Rankings.rank_of(w, Career.FIGHTER_ID), Titles.OFFER_FROM)
	assert_true(Matchmaker.shared().title_offer(c, rng).is_empty(), "not further down")


func test_winning_his_title_fight_makes_him_champion_and_then_he_only_defends_it() -> void:
	var c: Career = _career()
	_pro(c)
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	var week: int = Promotions.card_weeks(home, 1, 30)[0]
	c.week = week
	w = c.world()
	var k: String = Rankings.key(String(home.id), c.division)
	var champ: String = String(w.titles[k].champion)
	c.booked = { "opponent": champ, "week": week, "ruleset": "pro", "card": Promotions.card(w, home, week), "title": k }
	c.finish_fight({ "result": "win", "method": "Decision (unanimous)", "round": 5 })
	assert_eq(String(w.titles[k].champion), Career.FIGHTER_ID, "he's the champion")
	assert_eq(String(c.fights[-1].title), k)
	assert_string_contains(CareerHub.his_rank_text(c), "Champion")
	assert_string_contains(CareerHub.rankings_text(c), "Champion: Danny Hill")
	assert_string_contains(CareerHub.news_text(c, 2), "has won the")
	assert_false(Rankings.table(w, String(home.id), c.division).has(Career.FIGHTER_ID))
	c.week = week + Titles.DEFENCE_WEEKS
	w = c.world()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var offers: Array = c.matchmaker().make_offers(c, rng)
	assert_eq(offers.size(), 1, "a champion's only offer is his defence")
	assert_eq(String(offers[0].title_how), "defence")


func test_belts_are_saved_and_a_world_saved_before_them_gets_them() -> void:
	var c: Career = _career()
	c.world()
	c.run_week("time_off")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(JSON.stringify(back.world().titles), JSON.stringify(c.world().titles), "saved")
	var old: Dictionary = c.to_dict()
	old.world.erase("titles")
	var older: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	var w: World = older.world()
	assert_eq(w.titles.size(), c.world().titles.size(), "made when loaded")
	var champ: String = Titles.champion(w, "org_0", "lightweight")
	assert_false(Rankings.table(w, "org_0", "lightweight").has(champ), "and the champion taken out of the rankings")
