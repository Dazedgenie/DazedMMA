extends GutTest
## Climbing the ladder (sim/world/climb.gd, docs/03 §12.7, D357): his call-up after three wins in a row or a title
## defence, as an offer he can turn down; asking for a step up, a yes being a tryout on their card; let go after three
## losses in a row; title eliminators, the winner next in line; and his place on the ladder on the hub.


func _career(career_seed: int = 3) -> Career:
	var c: Career = Career.start({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country": "England",
		"background": "street_kid", "stance": "orthodox" }, career_seed, FighterLibrary.load_dir())
	c.trainee.age_years = 21.0
	c.pro = true
	c.division = c.natural_division()
	return c


func _new_year(c: Career) -> Callable:
	return func(w: int) -> Dictionary: return c.date(0, w)


## A pro fight on a card of `p`, against one of its men, booked and fought with `result`.
func _fight(c: Career, p: Dictionary, result: String, extra: Dictionary = {}) -> void:
	var w: World = c.world()
	var week: int = Promotions.card_weeks(p, c.week, c.week + 30)[0]
	c.week = week
	w = c.world()
	var men: Array = Rankings._men_of(w, String(p.id), c.division)
	var opponent: String = ""
	for m: Dictionary in men:
		if Titles.held_by(w, String(m.id)) == "" and not WorldWeeks._met_lately(m, Career.FIGHTER_ID, week):
			opponent = String(m.id)
			break
	c.booked = { "opponent": opponent, "week": week, "ruleset": "pro", "card": Promotions.card(w, p, week) }
	c.booked.merge(extra, true)
	c.finish_fight({ "result": result, "method": "Decision (unanimous)" if result != "draw" else "Draw", "round": 3 })
	c.week += 1


func test_three_wins_in_a_row_bring_a_call_up_he_can_turn_down() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	assert_eq(Climb.rung(w), Promotions.REGIONAL, "he starts on the regional cards")
	for i in 2:
		_fight(c, home, "win")
	assert_false(Climb.call_up_due(w), "two wins aren't enough")
	assert_string_contains(Climb.ladder_text(c), "2 of 3 wins in a row to a call-up to the %s" % String(Climb.up(w).short))
	_fight(c, home, "win")
	assert_true(Climb.call_up_due(w), "three wins in a row")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var offers: Array = c.matchmaker().make_offers(c, rng)
	var call_up: Array = offers.filter(func(o: Dictionary) -> bool: return String(o.get("step", "")) == Climb.CALL_UP)
	assert_eq(call_up.size(), 1, "one call-up among the offers")
	var o: Dictionary = call_up[0]
	assert_eq(String(o.to), String(Climb.up(w).id))
	assert_eq(String(o.card.promotion), String(Climb.up(w).id), "on their card")
	assert_eq(String(w.man(String(o.profile.id)).promotion), String(Climb.up(w).id), "against one of their men")
	assert_gt(offers.size(), 1, "with ordinary offers beside it")
	assert_string_contains(CareerHub.offer_text(c, o), "Call-up:")
	assert_false(Climb.call_up_due(w), "turned down or not, the next one waits for his next fight")
	c.offers = offers
	var to: Dictionary = Climb.up(w)
	assert_true(c.accept(String(o.id)))
	assert_eq(Climb.rung(w), Promotions.SECOND, "taking it signs him")
	assert_eq(String(w.him.promotion), String(Climb.organisation(w, Promotions.SECOND).id))
	assert_eq(Matchmaker.pro_cards(c, w, rng).keys(), [String(w.him.promotion)], "his offers come from them now")
	var said: Array = w.results.filter(func(r: Dictionary) -> bool: return String(r.get("kind", "")) == "moved" and String(r.id) == Career.FIGHTER_ID)
	assert_eq(said.size(), 1)
	assert_string_contains(CareerHub.news_text(c, 1), "has signed with the %s" % String(to.name))


func test_a_champion_is_offered_his_call_up_after_one_defence_and_his_belt_goes_with_it() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	var k: String = Rankings.key(String(home.id), c.division)
	_fight(c, home, "loss")
	Titles.crown(w, k, Career.FIGHTER_ID, c.week, "lost")
	w.titles[k].defences = Titles.CALL_UP_DEFENCES
	w.him.fights = int(w.him.fights) + 1
	assert_true(Climb.call_up_due(w), "after a defence")
	assert_string_contains(Climb.ladder_text(c), "after a title defence")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var offers: Array = c.matchmaker().make_offers(c, rng)
	var call_up: Array = offers.filter(func(o: Dictionary) -> bool: return String(o.get("step", "")) == Climb.CALL_UP)
	assert_eq(call_up.size(), 1, "a champion's offers: his defence when due, and his call-up")
	c.offers = offers
	c.accept(String(call_up[0].id))
	assert_eq(Titles.champion(w, String(home.id), c.division), "", "his belt goes vacant")


func test_three_losses_in_a_row_up_there_and_hes_let_go() -> void:
	var c: Career = _career()
	var w: World = c.world()
	w.him = { "id": Career.FIGHTER_ID, "name": "Danny Hill", "pro": true, "promotion": "", "division": c.division, "points": [] }
	Climb.sign_up(w, c.week, Climb.CALL_UP)
	var org: Dictionary = Climb.organisation(w, Promotions.SECOND)
	_fight(c, org, "loss")
	_fight(c, org, "loss")
	assert_string_contains(Climb.ladder_text(c), "2 losses in a row: 3 and he's let go")
	_fight(c, org, "loss")
	assert_eq(Climb.rung(w), Promotions.REGIONAL, "let go")
	assert_eq(String(w.him.promotion), String(Promotions.home(w).id), "back to his home promotion")
	assert_string_contains(CareerHub.fights_text(c), "let go")


func test_asking_for_a_step_up_a_yes_is_a_tryout_and_a_no_means_waiting() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	_fight(c, home, "win")
	Rankings.update(w, c.week, false)
	assert_true(Climb.can_ask(c))
	w.him.points = [[c.week, 60.0, Promotions.REGIONAL, 1, "w", "ko", ""]]
	Rankings.update(w, c.week, false)
	assert_eq(Climb.ask_chance(w), 0.7, "top 3: mostly yes")
	w.him.points = [[c.week, 0.5, Promotions.REGIONAL, 0, "w", "decision", ""]]
	Rankings.update(w, c.week, false)
	assert_lt(Climb.ask_chance(w), 0.7, "lower down: less likely")
	var yes: Dictionary = {}
	var no: Dictionary = {}
	for tries in 40:
		var a: Dictionary = c.ask_step_up()
		if a.is_empty():
			assert_false(Climb.can_ask(c), "he can't ask again so soon")
			c.week = Climb.next_ask_week(w)
			c.offers = []
			continue
		if bool(a.yes) and yes.is_empty():
			yes = a
			var tryouts: Array = c.offers.filter(func(o: Dictionary) -> bool: return String(o.get("step", "")) == Climb.TRYOUT)
			assert_eq(tryouts.size(), 1, "a yes is a tryout")
			assert_eq(String(tryouts[0].card.promotion), String(Climb.up(w).id))
			assert_string_contains(CareerHub.week_text(c), "said yes")
		elif not bool(a.yes) and no.is_empty():
			no = a
			assert_string_contains(CareerHub.week_text(c), "said no")
		if not yes.is_empty() and not no.is_empty():
			break
		c.week = Climb.next_ask_week(w)
		c.offers = []
	assert_false(yes.is_empty(), "sometimes yes")
	assert_false(no.is_empty(), "sometimes no")


func test_a_tryout_won_signs_him_and_a_tryout_lost_sends_him_back() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	_fight(c, home, "win")
	var org: Dictionary = Climb.up(w)
	_fight(c, org, "loss", { "step": Climb.TRYOUT })
	assert_eq(Climb.rung(w), Promotions.REGIONAL, "lost: still regional")
	assert_eq(String(w.him.promotion), String(home.id), "back where he was")
	_fight(c, org, "win", { "step": Climb.TRYOUT })
	assert_eq(Climb.rung(w), Promotions.SECOND, "won: signed")
	assert_eq(String(w.him.promotion), String(org.id))
	assert_string_contains(CareerHub.fights_text(c), "tryout")


func test_eliminators_put_the_winner_next_in_line_for_the_title() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var events: Array = WorldWeeks.advance(w, 104, {}, _new_year(c))
	var elims: Array = events.filter(func(r: Dictionary) -> bool: return r.has("eliminator"))
	assert_gt(elims.size(), 20, "eliminators between title fights")
	var shots: int = 0
	for r: Dictionary in elims:
		assert_between(int(r.ranks[0]), Titles.ELIMINATOR_FROM, Titles.ELIMINATOR_TO, "#3 to #6")
		assert_between(int(r.ranks[1]), Titles.ELIMINATOR_FROM, Titles.ELIMINATOR_TO)
		assert_lte(int(r.round), Titles.ELIMINATOR_ROUNDS)
		if String(r.winner) == "draw":
			continue
		var winner: String = String(r.a) if String(r.winner) == "a" else String(r.b)
		var next_title: Array = events.filter(func(t: Dictionary) -> bool:
			return String(t.get("title", "")) == String(r.eliminator) and int(t.week) > int(r.week))
		if not next_title.is_empty() and (String(next_title[0].a) == winner or String(next_title[0].b) == winner):
			shots += 1
	assert_gt(float(shots) / elims.size(), 0.5, "the winner mostly gets the next shot")
	for k: String in w.titles:
		var next: String = String(w.titles[k].get("next", ""))
		if next != "":
			assert_true(World.active(w.man(next)))
			assert_eq(Titles.waiting(w)[next], k)


func test_at_number_three_to_five_hes_offered_an_eliminator_and_winning_it_brings_his_shot() -> void:
	var c: Career = _career()
	var w: World = c.world()
	var home: Dictionary = Promotions.home(w)
	var k: String = Rankings.key(String(home.id), c.division)
	w.him = { "id": Career.FIGHTER_ID, "name": "Danny Hill", "pro": true, "promotion": String(home.id), "division": c.division,
		"points": [[c.week, 8.0, Promotions.REGIONAL, 0, "w", "ko", ""]] }
	Rankings.update(w, c.week, false)
	var rank: int = Rankings.rank_of(w, Career.FIGHTER_ID)
	if rank < Titles.ELIMINATOR_FROM or rank > Titles.HIS_ELIMINATOR_TO:
		var ids: Array = w.rankings[k]
		var pts: float = Rankings.score(w.man(String(ids[3])), Promotions.REGIONAL, c.week)
		w.him.points = [[c.week, pts + 0.01, Promotions.REGIONAL, 0, "w", "decision", ""]]
		Rankings.update(w, c.week, false)
	rank = Rankings.rank_of(w, Career.FIGHTER_ID)
	assert_between(rank, Titles.ELIMINATOR_FROM, Titles.HIS_ELIMINATOR_TO)
	w.titles[k].next = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var o: Dictionary = c.matchmaker().eliminator_offer(c, rng)
	assert_eq(String(o.get("eliminator", "")), k)
	assert_between(Rankings.rank_of(w, String(o.profile.id)), Titles.ELIMINATOR_FROM, Titles.ELIMINATOR_TO, "against a man of #3 to #6")
	assert_string_contains(CareerHub.offer_text(c, o), "Title eliminator")
	assert_true(Matchmaker.shared().title_offer(c, rng).is_empty(), "no shot yet")
	Titles.his_eliminator(w, k, "win", c.week)
	assert_eq(String(w.titles[k].next), Career.FIGHTER_ID)
	assert_string_contains(CareerHub.his_rank_text(c), "next in line")
	w.titles[k].last = c.week - Titles.DEFENCE_WEEKS
	var shot: Dictionary = c.matchmaker().title_offer(c, rng)
	assert_eq(String(shot.get("title_how", "")), "shot", "won it: his title shot")


func test_the_hub_shows_his_ladder_and_the_ask_button_and_his_climb_is_saved() -> void:
	var c: Career = _career()
	var w: World = c.world()
	_fight(c, Promotions.home(w), "win")
	assert_string_contains(CareerHub.fighter_card_text(c), "Ladder:")
	assert_string_contains(CareerHub.fighter_card_text(c), "1 of 3 wins in a row")
	var hub := CareerHub.new()
	add_child_autofree(hub)
	hub.show_career(c)
	assert_true(hub.can_ask())
	var asked: Array = []
	hub.ask_pressed.connect(func() -> void: asked.append(true))
	hub.press_ask()
	assert_eq(asked.size(), 1)
	c.ask_step_up()
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(JSON.stringify(back.world().him), JSON.stringify(c.world().him), "saved")
	assert_eq(Climb.next_ask_week(back.world()), Climb.next_ask_week(w))
	w.him.rung = Promotions.MAJOR
	assert_string_contains(Climb.ladder_text(c), "the top of the ladder")
	assert_false(Climb.can_ask(c), "nowhere higher to ask")
