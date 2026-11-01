extends GutTest
## One-day tournaments (sim/world/tournament.gd, Matchmaker.make_tournament and Career's booked tournament, docs/03
## §11.5, D315): every few months one of his offers is a four- or eight-man bracket fought in one day, damage carrying
## from fight to fight, with a medal for the top finishers.


func _career(career_seed: int = 1) -> Career:
	return Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "nickname": "The Kid", "hometown": "Leeds", "country": "England",
		"background": "wrestling_family", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())


## A career booked into a tournament of `size`, on fight night.
func _booked(size: int, career_seed: int = 1) -> Career:
	var c: Career = _career(career_seed)
	c.next_offers_week = 1000
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var o: Dictionary = c.matchmaker().make_tournament(c, rng, size)
	c.offers = [o]
	assert_true(c.accept(String(o.id)))
	while c.week < int(o.week):
		c.end_week()
	return c


## BBCode off a hub text.
func _plain(text: String) -> String:
	var tags := RegEx.create_from_string("\\[[^\\]]*\\]")
	return tags.sub(text, "", true)


func _win(c: Career, tank: float = 1.0, hurt: Dictionary = {}) -> void:
	c.finish_fight({ "result": "win", "method": "Unanimous decision", "round": 3, "tank": tank, "hurt": hurt })


func test_the_bracket_rules_name_the_rounds_and_give_the_medals() -> void:
	assert_eq(Tournament.rounds(4), 2)
	assert_eq(Tournament.rounds(8), 3)
	assert_eq(Tournament.stage_name(4, 0), "Semi-final")
	assert_eq(Tournament.stage_name(4, 1), "Final")
	assert_eq(Tournament.stage_name(8, 0), "Quarter-final")
	assert_eq(Tournament.stage_name(8, 2), "Final")
	assert_eq(Tournament.medal(8, 2, true), Tournament.GOLD)
	assert_eq(Tournament.medal(8, 2, false), Tournament.SILVER)
	assert_eq(Tournament.medal(8, 1, false), Tournament.BRONZE, "a semi-final he won a quarter-final to reach")
	assert_eq(Tournament.medal(8, 0, false), "", "out in the quarter-final")
	assert_eq(Tournament.medal(4, 0, false), "", "a four-man open's semi-final losers get nothing, or every man would medal")
	assert_eq(Tournament.medal(4, 1, false), Tournament.SILVER)


func test_what_he_carries_into_the_next_round() -> void:
	var carry: Dictionary = Tournament.carry_over(0.95, { "head": 0.4, "body": 0.1, "legs": 0.0 })
	assert_almost_eq(float(carry.tank), 0.95 - Tournament.TANK_PER_FIGHT, 0.001, "a smaller gas tank each fight")
	assert_almost_eq(float(carry.hurt.head), 0.4 * Tournament.CARRY_HURT, 0.001, "most of the damage stays")
	assert_false(carry.hurt.has("legs"), "nothing to carry")
	assert_eq(float(Tournament.carry_over(0.0, {}).tank), TrainingCamp.TANK_FLOOR, "never under the floor")


func test_a_tournament_comes_as_one_of_his_offers_every_few_months() -> void:
	var c: Career = _career()
	assert_eq(c.next_tournament_week, Tournament.FIRST_WEEK, "not in his first weeks")
	c.next_tournament_week = 1
	c.run_week("time_off")
	assert_gt(c.offers.size(), 1)
	var o: Dictionary = c.offers[-1]
	assert_true(o.get("tournament") is Dictionary, "the last offer is a tournament")
	assert_false(c.offers[0].has("tournament"), "the others are single fights")
	assert_between(c.next_tournament_week, c.week + Tournament.GAP_MIN, c.week + Tournament.GAP_MAX, "the next in 3 to 4 months")
	var size: int = int(o.tournament.size)
	assert_true(size in Tournament.SIZES)
	assert_eq((o.tournament.rest as Array).size(), Tournament.rounds(size) - 1, "a man for every round")
	assert_string_ends_with(String(o.card.name), str(int(c.date(5, int(o.week)).year)))  # Named by its year.
	assert_string_contains(String(o.card.name), String(o.card.city))
	assert_string_contains(_plain(CareerHub.offer_text(c, o)), "One-day tournament: %d men" % size)
	var pro: Career = _career(2)
	pro.pro = true
	pro.next_tournament_week = 1
	pro.run_week("time_off")
	for p: Dictionary in pro.offers:
		assert_false(p.has("tournament"), "tournaments are for amateurs")


func test_the_men_he_would_meet_get_harder_and_more_tired_round_by_round() -> void:
	var c: Career = _career()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var o: Dictionary = c.matchmaker().make_tournament(c, rng, 8)
	assert_eq(String(o.difficulty), "tournament")
	var men: Array = [{ "profile": o.profile, "style": o.style }]
	men.append_array(o.tournament.rest)
	assert_eq(men.size(), 3)
	var ids: Array = []
	var styles: Array = []
	for i in men.size():
		ids.append(String(men[i].profile.id))
		styles.append(String(men[i].style))
		var tank: float = float(men[i].profile.get("condition", {}).get("tank", 1.0))
		assert_almost_eq(tank, Tournament.OPPONENT_TANK[i], 0.001, "the later men have had fights too")
	for id: String in ids:
		assert_eq(ids.count(id), 1, "a different man each round")
	for s: String in styles:
		assert_eq(styles.count(s), 1, "a different style each round")


func test_winning_a_round_keeps_him_on_for_the_next_the_same_day() -> void:
	var c: Career = _booked(4)
	var week: int = c.week
	assert_eq(c.tournament_stage(), 0)
	var men: Array = c.booked.tournament.men
	for m: Dictionary in men:
		assert_true(c.opponents.has(String(m.id)), "every man he'd meet is known")
	assert_string_contains(_plain(CareerHub.week_text(c)), "a one-day tournament for 4")
	_win(c, 0.9, { "head": 0.3 })
	assert_eq(c.week, week, "the same day: the week isn't over")
	assert_eq(c.tournament_stage(), 1, "through to the final")
	assert_eq(String(c.booked.opponent), String(men[1].id))
	assert_eq(c.fights.size(), 1, "the semi-final is on his record")
	assert_eq(String(c.fights[-1].tournament.name), c.tournament_name())
	var p: Dictionary = c.round_profile()
	assert_almost_eq(float(p.condition.tank), 0.8, 0.001, "a smaller gas tank")
	assert_almost_eq(float(p.condition.hurt.head), 0.3 * Tournament.CARRY_HURT, 0.001, "still hurt from the semi-final")
	assert_string_contains(_plain(CareerHub.week_text(c)), "the final of the")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.tournament_stage(), 1, "a save between rounds carries on")
	assert_eq(String(back.booked_opponent().name), String(c.booked_opponent().name))
	_win(c, float(p.condition.tank))
	assert_true(c.booked.is_empty(), "his day's over")
	assert_eq(c.week, week + 1)
	assert_eq(c.medals.size(), 1)
	assert_eq(String(c.medals[0].medal), Tournament.GOLD, "won it")
	assert_eq(String(c.fights[-1].medal), Tournament.GOLD)
	assert_eq(c.record_text(false), "2-0-0", "two fights on his record")
	assert_string_contains(_plain(CareerHub.fighter_card_text(c)), "Medals: gold, " + String(c.medals[0].name))
	assert_string_contains(_plain(CareerHub.fights_text(c)), "final · gold")
	var saved: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(saved.medals.size(), 1, "medals are saved")
	assert_eq(int(saved.medals[0].size), 4)


func test_a_loss_ends_his_day_with_the_medal_for_that_round() -> void:
	var semi: Career = _booked(4)
	semi.finish_fight({ "result": "loss", "method": "KO", "round": 1 })
	assert_true(semi.booked.is_empty())
	assert_true(semi.medals.is_empty(), "out in a four-man semi-final: no medal")
	assert_eq(semi.opponents.keys(), [String(semi.fights[-1].opponent)], "the finalist he never met goes")
	var eight: Career = _booked(8)
	_win(eight)
	eight.finish_fight({ "result": "draw", "method": "Split draw", "round": 3 })
	assert_eq(String(eight.medals[0].medal), Tournament.BRONZE, "a draw puts him out; a semi-final loss is bronze")
	assert_eq(eight.opponents.size(), 2, "the two men he met")
	var final: Career = _booked(4)
	_win(final)
	final.finish_fight({ "result": "loss", "method": "Submission", "round": 2 })
	assert_eq(String(final.medals[0].medal), Tournament.SILVER)


func test_the_suspension_is_the_worst_of_his_day() -> void:
	var c: Career = _booked(4)
	c.finish_fight({ "result": "win", "method": "KO", "round": 1, "hard": true, "tank": 1.0, "hurt": { "head": 0.8 } })
	assert_eq(c.suspended_days, 0, "no suspension until his day's over")
	assert_eq(int(c.fights[-1].suspension_days), Aftermath.HARD_DAYS, "a hard semi-final")
	c.finish_fight({ "result": "win", "method": "Unanimous decision", "round": 3 })
	assert_eq(c.suspended_days, Aftermath.HARD_DAYS - Career.FIGHT_TO_MONDAY, "the hard semi-final's suspension, from the end of the day")
	assert_eq(int(c.fights[-1].suspension_days), Aftermath.HARD_DAYS)
	assert_string_contains(String(c.fights[-1].suspension_why), "earlier in the day")


func test_pulling_out_between_rounds_keeps_the_medal_for_the_round_he_missed() -> void:
	var c: Career = _booked(8)
	var men: Array = c.booked.tournament.men.duplicate(true)
	assert_eq(c.withdraw(), "", "nothing to pull out of before his first fight")
	_win(c)
	_win(c)
	assert_eq(c.tournament_stage(), 2, "through to the final")
	assert_eq(c.withdraw(), Tournament.SILVER, "too hurt for the final: silver")
	assert_true(c.booked.is_empty())
	assert_true(bool(c.fights[-1].withdrew))
	assert_false(c.opponents.has(String(men[2].id)), "the finalist he never met goes")
	assert_true(c.opponents.has(String(men[1].id)))


func test_pulling_out_before_the_day_drops_every_man() -> void:
	var c: Career = _booked(8)
	var men: Array = c.booked.tournament.men.duplicate(true)
	c.cancel_fight()
	for m: Dictionary in men:
		assert_false(c.opponents.has(String(m.id)))
	assert_true(c.medals.is_empty())
