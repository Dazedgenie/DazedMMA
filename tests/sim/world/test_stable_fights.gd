extends GutTest
## Your stable's fights (sim/world/stable.gd, docs/03 §14.6, D445's second piece): booked about three weeks ahead
## against a man near his level, held back from the world's pairings, a fight night that stops Advance, played or
## simmed onto the world, decided by the quick result when left alone, turned down, saved.


func _career(members: int = 40) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 16
	p.potential = 80
	var gym := { "kind": "mma_gym", "culture": "family", "place": "unit", "name": "Test Gym", "owner_name": "Frank Doyle",
		"owner": "Owns it.", "dues": 40, "members": members, "members_start": members, "rent": Gym.rent_for(members, 40) }
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym, "country": "England", "hometown": "Leeds" })
	c.gym_money = 2000
	c.next_offers_week = 1000
	return c


## Signs the first prospect who's `pro` (or not) and isn't one of the gym's lads, with a sure roll.
func _sign(c: Career, pro: bool) -> Dictionary:
	for m: Dictionary in c.stable_prospects():
		if bool(m.get("pro", false)) == pro and not Lads.lads(c.gym).any(func(l: Dictionary) -> bool: return String(l.id) == String(m.id)):
			assert_eq(Stable.offer(c.world(), c.gym, m, c.week, 0.0), "")
			return m
	return {}


## Runs weeks until he has a booking (at most `weeks`).
func _until_booked(c: Career, id: String, weeks: int = 30) -> Dictionary:
	for i in weeks:
		var b: Dictionary = Stable.booking(Stable.entry(c.gym, id))
		if not b.is_empty():
			return b
		c.end_week()
	return Stable.booking(Stable.entry(c.gym, id))


func test_a_signed_man_is_booked_three_weeks_ahead_against_a_man_near_his_level() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign(c, false)
	var b: Dictionary = _until_booked(c, String(m.id))
	assert_false(b.is_empty(), "booked")
	var w: World = c.world()
	var opp: Dictionary = w.man(String(b.opponent))
	assert_gte(int(b.week), c.week + Stable.LEAD_WEEKS - 1)
	assert_eq(World.division_of(opp, int(b.week)), World.division_of(m, int(b.week)), "his division")
	assert_eq(bool(opp.pro), bool(m.pro))
	assert_lt(WorldWeeks.pair_gap(w, m, opp), Stable.MATCH_GAP, "near his level")
	assert_false(Lads.at_gym(c.gym, String(opp.id)), "not a gym-mate")
	assert_eq(String(b.ruleset), Stable.ruleset_for(m, int(b.week)))
	var held: Dictionary = Stable.busy(c.gym)
	assert_true(held.has(String(m.id)) and held.has(String(opp.id)), "both held back from the world's pairings")


func test_a_pro_is_booked_on_his_promotions_card() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign(c, true)
	assert_false(m.is_empty(), "a pro to sign")
	var b: Dictionary = _until_booked(c, String(m.id))
	assert_false(b.is_empty(), "booked")
	var p: Dictionary = Promotions.of(c.world(), m)
	assert_true(Promotions.has_card(p, int(b.week)), "a card week")
	assert_eq(String(b.card), String(Promotions.card(c.world(), p, int(b.week)).short))
	assert_eq(String(b.promotion), String(p.id))
	assert_eq(String(c.world().man(String(b.opponent)).promotion), String(p.id), "on the same promotion")


func test_fight_night_stops_advance_and_the_calendar_shows_it() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign(c, false)
	var b: Dictionary = _until_booked(c, String(m.id))
	var ahead: Array = c.calendar().filter(func(wk: Dictionary) -> bool:
		return (wk.events as Array).any(func(e: Dictionary) -> bool: return String(e.kind) == Career.STABLE_FIGHT_NIGHT))
	assert_eq(ahead.size(), 1, "on the calendar")
	assert_eq(int(ahead[0].week), int(b.week))
	while c.week < int(b.week) - 1:
		c.end_week()
	c.stable_news = []
	var reports: Array[Dictionary] = c.advance()
	assert_eq(reports.size(), 1, "Advance stops at the start of his fight week")
	var kinds: Array = reports[-1].events.map(func(e: Dictionary) -> String: return String(e.kind))
	assert_true(Career.STABLE_FIGHT_NIGHT in kinds, str(kinds))
	assert_eq(Stable.due(c.gym, c.week).size(), 1)
	assert_false(c.stable_fight(String(m.id)).is_empty(), "ready to play")


func test_a_played_fight_goes_onto_the_world_and_pays_the_gym() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign(c, true)
	var b: Dictionary = _until_booked(c, String(m.id))
	while c.week < int(b.week):
		c.end_week()
	var f: Dictionary = c.stable_fight(String(m.id))
	assert_eq(String(f.red.id), String(m.id))
	assert_eq(String(f.blue.id), String(b.opponent))
	var w: World = c.world()
	var wins_before: int = int(w.man(String(m.id)).record.win)
	var money: int = c.gym_money
	var lines: Array[String] = c.finish_stable_fight(String(m.id), "win", FightSim.RESULT_TKO, 2, 77)
	assert_eq(int(w.man(String(m.id)).record.win), wins_before + 1)
	assert_eq(String(w.man(String(b.opponent)).history[-1][2]), "l", "a loss for the other man")
	assert_gt(c.gym_money, money, "the gym's cut")
	assert_string_contains(lines[0], "by knockout")
	assert_true(Stable.booking(Stable.entry(c.gym, String(m.id))).is_empty(), "the booking's done")
	assert_true(c.stable_fight(String(m.id)).is_empty())
	assert_eq(c.finish_stable_fight(String(m.id), "win", "ko", 1, 1), [] as Array[String], "only once")


func test_a_fight_left_alone_is_decided_by_the_quick_result_when_the_week_ends() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign(c, false)
	var b: Dictionary = _until_booked(c, String(m.id))
	while c.week < int(b.week):
		c.end_week()
	var fights_before: int = (c.world().man(String(m.id)).history as Array).size()
	var report: Dictionary = c.run_week()
	var h: Array = c.world().man(String(m.id)).history
	assert_eq(h.size(), mini(fights_before + 1, WorldWeeks.HISTORY), "he fought")
	assert_eq(String(h[-1][1]), String(b.opponent))
	assert_eq(int(h[-1][0]), int(b.week))
	var kinds: Array = report.events.map(func(e: Dictionary) -> String: return String(e.kind))
	assert_true(Career.STABLE_FOUGHT in kinds, str(kinds))


func test_turning_a_fight_down_frees_the_other_man_and_he_waits_a_month() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign(c, false)
	var b: Dictionary = _until_booked(c, String(m.id))
	assert_true(c.turn_down_stable_fight(String(m.id)))
	assert_false(Stable.busy(c.gym).has(String(b.opponent)))
	assert_false(c.turn_down_stable_fight(String(m.id)), "nothing left to turn down")
	var turned: int = c.week
	for i in Stable.TURN_DOWN_WEEKS - Stable.LEAD_WEEKS:
		c.end_week()
		var again: Dictionary = Stable.booking(Stable.entry(c.gym, String(m.id)))
		assert_true(again.is_empty() or int(again.week) >= turned + Stable.TURN_DOWN_WEEKS, "not before the wait's up")


func test_a_booked_man_isnt_unhappy_for_waiting() -> void:
	var e := { "since": 0, "booked": { "opponent": "x", "week": 40 } }
	assert_eq(Stable.unhappy_reasons({ "history": [] }, e, Stable.IDLE_WEEKS + 1, 100), [] as Array[String])


func test_the_bookings_save_and_load() -> void:
	var c: Career = _career()
	var m: Dictionary = _sign(c, false)
	var b: Dictionary = _until_booked(c, String(m.id))
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var again: Dictionary = Stable.booking(Stable.entry(back.gym, String(m.id)))
	assert_eq(typeof(again.week), TYPE_INT)
	assert_eq(int(again.week), int(b.week))
	assert_eq(String(again.opponent), String(b.opponent))
	Stable.month(back.world(), back.gym, back.week, 100)
	assert_false(Stable.booking(Stable.entry(back.gym, String(m.id))).is_empty(), "the month's refresh keeps it")


func test_the_news_reads_plainly() -> void:
	assert_eq(Stable.news_text({ "kind": Stable.BOOKED, "name": "Jake Moss", "opponent": "Tom Reid", "card": "NCC 14" }),
		"Jake Moss is booked to fight Tom Reid on NCC 14")
	assert_string_contains(Stable.news_text({ "kind": Stable.FIGHT_NIGHT, "name": "Jake Moss", "opponent": "Tom Reid" }), "Play it or sim it")
	assert_true(Career.STABLE_BOOKED in Career.JUST_NEWS, "a booking doesn't stop Advance")
	assert_false(Career.STABLE_FIGHT_NIGHT in Career.JUST_NEWS, "fight night does")
	for kind: String in [Career.STABLE_BOOKED, Career.STABLE_FIGHT_NIGHT]:
		assert_ne(CalendarIcon.colour_of(kind), Color("#adb5bd"), kind)
