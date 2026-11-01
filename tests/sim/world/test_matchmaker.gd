extends GutTest
## Fight offers (sim/world/matchmaker.gd and Career's offers, docs/03 §10.4, D304): who's offered, when, under which
## rules and for what money; taking one, turning one down, the fight and turning pro.


func _career(career_seed: int = 1, age: int = 16) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "nickname": "The Kid", "hometown": "Leeds", "country": "England",
		"background": "wrestling_family", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


func _kinds(report: Dictionary) -> Array:
	return report.events.map(func(e: Dictionary) -> String: return e.kind)


func _average(stats: Dictionary) -> float:
	var total: float = 0.0
	for id: String in StyleLibrary.stat_ids():
		total += float(stats.get(id, FighterState.DEFAULT_STAT))
	return total / StyleLibrary.stat_ids().size()


func test_offers_come_once_he_is_free_two_or_three_at_a_time() -> void:
	var c: Career = _career()
	assert_true(c.offers.is_empty(), "nothing on his first Monday")
	var report: Dictionary = c.run_week("time_off")
	assert_true(Career.OFFERS in _kinds(report), "after his first week")
	assert_between(c.offers.size(), Matchmaker.OFFERS_MIN, Matchmaker.OFFERS_MAX)
	var styles: Array = []
	var kinds: Array = []
	for o: Dictionary in c.offers:
		styles.append(o.style)
		kinds.append(o.difficulty)
		assert_eq(o.ruleset, Matchmaker.TEEN_RULES, "a 16-year-old fights under teen amateur rules")
		assert_true(o.purse.is_empty(), "amateurs aren't paid")
		assert_between(int(o.profile.age), 16, 17, "teenagers meet teenagers")
		assert_between(int(o.week) - c.week + 1, Matchmaker.CAMP_WEEKS_MIN + 1, Matchmaker.CAMP_WEEKS_MAX, "a camp of 5-8 weeks taken now")
		assert_eq(int(o.expires), c.week + 1, "open this week and next")
		assert_ne(String(o.profile.name), "")
		assert_ne(String(o.about.hometown), "")
	assert_true("even" in kinds, "one about even")
	for s: String in styles:
		assert_eq(styles.count(s), 1, "a different style each")
	assert_string_contains(Career.event_text(report.events[-1]), "fight offers")


func test_no_offers_while_he_is_hurt_or_suspended() -> void:
	var c: Career = _career()
	c.trainee.injured_days = 30
	c.trainee.injury_area = "legs"
	c.run_week("time_off")
	assert_true(c.offers.is_empty(), "hurt")
	c.trainee.injured_days = 0
	c.suspended_days = 30
	c.run_week("time_off")
	assert_true(c.offers.is_empty(), "suspended")
	c.suspended_days = 0
	c.run_week("time_off")
	assert_false(c.offers.is_empty(), "free again")


func test_offers_left_alone_go_and_new_ones_come_later() -> void:
	var c: Career = _career()
	c.week_plan = "time_off"
	c.run_week("time_off")
	var first: String = String(c.offers[0].id)
	c.run_week("time_off")
	assert_eq(String(c.offers[0].id), first, "still open the week after")
	c.run_week("time_off")
	assert_true(c.offers.is_empty(), "gone after two weeks")
	var reports: Array[Dictionary] = c.advance()
	assert_true(Career.OFFERS in _kinds(reports[-1]), "Advance stops when the next ones come")
	assert_between(reports.size(), Matchmaker.GAP_MIN, Matchmaker.GAP_MAX)


func test_a_harder_offer_is_a_better_man_than_an_easier_one() -> void:
	var c: Career = _career()
	var m: Matchmaker = Matchmaker.shared()
	for style_id: String in ["boxer", "wrestler", "bjj"]:
		var easy_rng := RandomNumberGenerator.new()
		easy_rng.seed = 9
		var hard_rng := RandomNumberGenerator.new()
		hard_rng.seed = 9
		var easier: Dictionary = m.make_offer(c, style_id, "easier", easy_rng)
		var harder: Dictionary = m.make_offer(c, style_id, "harder", hard_rng)
		assert_gt(_average(harder.profile.stats), _average(easier.profile.stats), style_id)
	var even_rng := RandomNumberGenerator.new()
	even_rng.seed = 9
	var even: Dictionary = m.make_offer(c, "boxer", "even", even_rng)
	assert_almost_eq(_average(even.profile.stats), _average(c.profile().stats), 4.0, "about even is about his level")


func test_taking_an_offer_books_the_fight_and_starts_the_camp() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	var o: Dictionary = c.offers[0]
	assert_true(c.accept(String(o.id)))
	assert_true(c.offers.is_empty(), "the other offers go")
	assert_eq(String(c.booked.opponent), String(o.profile.id))
	assert_false(c.booked.has("profile"), "the man himself is kept with the others he's met")
	assert_eq(String(c.booked_opponent().name), String(o.profile.name))
	assert_eq(c.camp_weeks_left(), int(o.week) - c.week + 1)
	assert_true(c.advance().is_empty(), "the camp runs his weeks now")
	var weeks: Array[Dictionary] = c.calendar(Career.CALENDAR_WEEKS)
	var nights: Array = []
	for i in weeks.size():
		for e: Dictionary in weeks[i].events:
			if e.kind == Career.FIGHT_NIGHT:
				nights.append(i)
	assert_eq(nights, [c.camp_weeks_left() - 1], "the calendar shows fight night")
	assert_false(c.accept(String(o.id)), "already booked")


func test_turning_an_offer_down_takes_only_that_one() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	var count: int = c.offers.size()
	c.decline(String(c.offers[0].id))
	assert_eq(c.offers.size(), count - 1)
	assert_true(c.booked.is_empty())


func test_the_fight_goes_on_his_record_and_ends_the_week() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	var o: Dictionary = c.offers[0]
	c.accept(String(o.id))
	while c.week < int(o.week):
		c.end_week()
	var paid: int = c.finish_fight({ "result": "win", "method": "KO", "round": 1 })
	assert_eq(paid, 0, "an amateur")
	assert_eq(c.record_text(false), "1-0-0")
	assert_eq(String(c.fights[-1].opponent), String(o.profile.id))
	assert_eq(int(c.fights[-1].week), int(o.week), "dated fight week")
	assert_eq(String(c.fights[-1].ruleset), Matchmaker.TEEN_RULES)
	assert_eq(c.week, int(o.week) + 1, "the week's over")
	assert_true(c.booked.is_empty())
	assert_true(c.opponents.has(String(o.profile.id)), "the man he fought is kept")
	assert_gt(c.next_offers_week, c.week, "a rest before the next offers")


func test_pulling_out_cancels_the_fight() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	var o: Dictionary = c.offers[0]
	c.accept(String(o.id))
	c.cancel_fight()
	assert_true(c.booked.is_empty())
	assert_false(c.opponents.has(String(o.profile.id)), "he never fought him")
	assert_true(c.fights.is_empty())


func test_he_can_turn_pro_at_18_after_four_amateur_fights_and_gets_paid() -> void:
	var c: Career = _career()
	c.trainee.age = 18
	c.trainee.age_years = 18.0
	assert_eq(Matchmaker.rules_for(c), Matchmaker.ADULT_RULES, "adult amateur from 18")
	assert_false(Matchmaker.can_turn_pro(c), "no fights yet")
	c.add_opponent({ "id": "opp_1", "name": "First Man" })
	for i in Matchmaker.PRO_AFTER_FIGHTS:
		c.add_fight({ "result": "win", "opponent": "opp_1" })
	assert_true(Matchmaker.can_turn_pro(c))
	assert_true(c.turn_pro())
	assert_true(c.pro)
	assert_false(Matchmaker.can_turn_pro(c), "once")
	assert_eq(Matchmaker.rules_for(c), Matchmaker.PRO_RULES)
	assert_eq(Matchmaker.purse_for(c), { "show": Matchmaker.PURSE_SHOW, "win": Matchmaker.PURSE_WIN }, "no pro wins yet")
	c.run_week("time_off")
	assert_false(c.offers.is_empty(), "pro offers the week after")
	var o: Dictionary = c.offers[0]
	assert_eq(String(o.ruleset), Matchmaker.PRO_RULES)
	assert_true((o.card as Dictionary).is_empty(), "local cards are for amateurs (D314)")
	var money: int = c.money
	c.accept(String(o.id))
	assert_eq(c.finish_fight({ "result": "win", "method": "KO", "round": 1 }), Matchmaker.PURSE_SHOW + Matchmaker.PURSE_WIN, "show and win")
	assert_eq(c.money, money + Matchmaker.PURSE_SHOW + Matchmaker.PURSE_WIN)
	assert_eq(c.record_text(true), "1-0-0")
	assert_eq(int(Matchmaker.purse_for(c).show), Matchmaker.PURSE_SHOW + Matchmaker.PURSE_STEP, "a win raises the purse")


func test_a_teenager_cannot_turn_pro() -> void:
	var c: Career = _career()
	c.add_opponent({ "id": "opp_1", "name": "First Man" })
	for i in 6:
		c.add_fight({ "result": "win", "opponent": "opp_1" })
	assert_false(Matchmaker.can_turn_pro(c))
	assert_false(c.turn_pro())


func test_offers_and_a_booked_fight_come_back_from_a_save() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict(), "", true, true))
	var back: Career = Career.from_dict(saved)
	assert_eq(back.offers.size(), c.offers.size())
	assert_eq(String(back.offers[0].profile.name), String(c.offers[0].profile.name))
	assert_eq(back.next_offers_week, c.next_offers_week)
	assert_true(back.accept(String(back.offers[0].id)))
	var again: Career = Career.from_dict(JSON.parse_string(JSON.stringify(back.to_dict(), "", true, true)))
	assert_eq(again.camp_weeks_left(), back.camp_weeks_left())
	assert_eq(String(again.booked_opponent().name), String(back.booked_opponent().name))


func test_the_same_career_gets_the_same_offers() -> void:
	var a: Career = _career(4)
	var b: Career = _career(4)
	a.run_week("time_off")
	b.run_week("time_off")
	assert_eq(JSON.stringify(a.offers), JSON.stringify(b.offers))


func test_amateur_offers_are_on_named_local_cards_against_local_lads() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	assert_false(c.offers.is_empty())
	var england: Array = NameLibrary.shared().cities("england")
	for o: Dictionary in c.offers:
		var card: Dictionary = o.card
		assert_ne(String(card.name), "", "every amateur offer is on a card")
		assert_false(String(card.name).contains("{"), "the name's filled in")
		assert_true(String(card.city) in england, "a card in his country")
		assert_string_contains(String(card.name), String(card.city))
		assert_ne(String(card.venue), "")
		assert_eq(String(o.about.country), "England", "a local lad")
		assert_string_contains(CareerHub.offer_text(c, o), "On %s · the %s, %s" % [card.name, card.venue, card.city])
	var o: Dictionary = c.offers[0]
	assert_true(c.accept(String(o.id)))
	assert_string_contains(CareerHub.week_text(c), "on " + String(o.card.name))
	c.finish_fight({ "result": "win", "method": "KO", "round": 1 })
	assert_eq(String(c.fights[-1].card.name), String(o.card.name), "the fight keeps the card it was on")
	assert_string_contains(CareerHub.fights_text(c), String(o.card.name))
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(String(back.fights[-1].card.name), String(o.card.name), "saved")


func test_a_card_series_keeps_its_venue_and_counts_up() -> void:
	var c: Career = _career()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var first: Dictionary = c.matchmaker().local_card(c, rng, "england")
	c.week = 16
	rng.seed = 11
	var later: Dictionary = c.matchmaker().local_card(c, rng, "england")
	assert_eq(later.city, first.city)
	assert_eq(later.venue, first.venue, "the same series is at the same place")
	var number := func(card: Dictionary) -> int: return String(card.name).get_slice(" ", String(card.name).get_slice_count(" ") - 1).to_int()
	assert_eq(number.call(later), number.call(first) + 2, "one more every 8 weeks")
	assert_eq(Matchmaker.card_text({ "name": "Leeds Fight Night 4", "venue": "Sports Centre", "city": "Leeds" }),
		"Leeds Fight Night 4 · the Sports Centre, Leeds")
	assert_eq(Matchmaker.card_text({}), "")


func test_at_18_the_hub_says_whether_turning_pro_looks_wise() -> void:
	var c: Career = _career()
	assert_true(Matchmaker.pro_advice(c).is_empty(), "nothing to say at 16")
	c.trainee.age = 18
	c.trainee.age_years = 18.0
	assert_eq(String(Matchmaker.pro_advice(c).word), Matchmaker.PRO_NOT_YET)
	assert_string_contains(String(Matchmaker.pro_advice(c).text), "after 4 more amateur fights")
	c.add_opponent({ "id": "opp_1", "name": "First Man" })
	for result: String in ["win", "win", "loss", "win"]:
		c.add_fight({ "result": result, "opponent": "opp_1" })
	assert_eq(String(Matchmaker.pro_advice(c).word), Matchmaker.PRO_RISKY, "3-1, but a 16-year-old's skills")
	assert_string_contains(String(Matchmaker.pro_advice(c).text), "skills")
	for id: String in StyleLibrary.stat_ids():
		c.trainee.stats[id] = 45.0
	assert_eq(String(Matchmaker.pro_advice(c).word), Matchmaker.PRO_WISE)
	assert_string_contains(CareerHub.week_text(c), "Turning pro looks wise: 3-1-0 as an amateur")
	c.trainee.age = Matchmaker.PRO_LATE_AGE
	assert_eq(String(Matchmaker.pro_advice(c).word), Matchmaker.PRO_LATE, "waiting costs him prime years")
	for i in 3:
		c.add_fight({ "result": "loss", "opponent": "opp_1" })
	assert_eq(String(Matchmaker.pro_advice(c).word), Matchmaker.PRO_RISKY, "3-4: a few more wins first")
	assert_true(c.turn_pro(), "advice only: the choice is yours")
	assert_true(Matchmaker.pro_advice(c).is_empty())
