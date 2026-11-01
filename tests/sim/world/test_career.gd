extends GutTest
## Career (sim/world/career.gd, docs/03 §10.1, D301): one fighter's career, its calendar and record, and a save
## that brings it back exactly.


func _fighter(age: int = 16) -> Dictionary:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = age
	p.potential = 80
	return p


func _career(career_seed: int = 1) -> Career:
	return Career.create(_fighter(), career_seed, { "coach": "Sam", "nickname": "The Hammer", "hometown": "Leeds", "country": "England", "background": "wrestling_family" })


## What a save file holds: the career written out as JSON and read back.
func _through_json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data, "", true, true))


func _text(data: Dictionary) -> String:
	return JSON.stringify(_through_json(data), "", true, true)


func test_a_new_career_starts_on_monday_4_january_2027_with_no_fights() -> void:
	var c: Career = _career()
	assert_eq(c.week, 0)
	assert_eq(c.date_text(), "Mon 4 Jan 2027")
	assert_eq(c.record_text(false), "0-0-0")
	assert_eq(c.record_text(true), "0-0-0")
	assert_false(c.pro)
	assert_eq(c.coach_name, "Sam")
	assert_eq(c.about.nickname, "The Hammer")
	assert_eq(c.fighter_name(), "Wrestler")
	assert_eq(c.age(), 16)
	assert_eq(c.profile().id, Career.FIGHTER_ID, "the fighter has his own id in fights and saved records")
	assert_false(c.profile().has("condition"), "he starts the career fresh")


func test_the_calendar_counts_days_and_knows_leap_years() -> void:
	assert_eq(Career.days_from_civil(1970, 1, 1), 0)
	assert_eq(Career.days_from_civil(2027, 1, 4), 20822)
	assert_eq(str(Career.civil_from_days(20822)), "[2027, 1, 4]")
	assert_eq(str(Career.civil_from_days(21243)), "[2028, 2, 29]")
	assert_eq(str(Career.civil_from_days(11017)), "[2000, 3, 1]")
	var c: Career = _career()
	c.week = 60
	assert_eq(c.date_text(5), "Sat 4 Mar 2028")


func test_a_week_between_fights_moves_the_calendar_and_makes_him_a_week_older() -> void:
	var c: Career = _career()
	var born: float = c.trainee.age_years
	var report: Dictionary = c.run_week()
	assert_eq(report.plan, Career.BETWEEN_PLAN, "between fights he runs the lighter week (docs/02 §3.8)")
	assert_eq(c.week, 1)
	assert_eq(c.date_text(), "Mon 11 Jan 2027")
	assert_almost_eq(c.trainee.age_years, born + 1.0 / 52.0, 0.000001)
	for i in 51:
		c.run_week()
	assert_eq(c.age(), 17, "a year of weeks is a birthday")


func test_a_suspension_runs_down_a_week_at_a_time() -> void:
	var c: Career = _career()
	c.suspended_days = 10
	c.run_week()
	assert_eq(c.suspended_days, 3)
	c.run_week()
	assert_eq(c.suspended_days, 0)


func test_an_injury_heals_while_he_rests_between_fights() -> void:
	var c: Career = _career()
	c.trainee.injured_days = 5
	c.trainee.injury_area = "legs"
	c.run_week("time_off")
	assert_eq(c.trainee.injured_days, 0, "seven nights' healing in a week off")


func test_the_record_keeps_amateur_and_pro_fights_apart() -> void:
	var c: Career = _career()
	c.add_opponent({ "id": "opp_1", "name": "First Man" })
	c.add_fight({ "result": "win", "opponent": "opp_1", "method": "KO", "round": 1 })
	c.run_week()
	c.add_fight({ "result": "loss", "opponent": "opp_1", "method": "Decision", "round": 3 })
	c.pro = true
	c.add_fight({ "result": "win", "opponent": "opp_1" })
	c.add_fight({ "result": "no_contest", "opponent": "opp_1" })
	assert_eq(c.record_text(false), "1-1-0")
	assert_eq(c.record_text(true), "1-0-0, 1 NC")
	assert_eq(c.fights[0].week, 0)
	assert_eq(c.fights[1].week, 1, "each fight is dated the week it happened")
	assert_true(c.opponents.has("opp_1"), "the man he fought is kept, so a rematch is the same man")


func test_a_career_comes_back_from_its_save_exactly() -> void:
	var c: Career = _career(7)
	for i in 3:
		c.run_week("all_out")
	c.add_opponent({ "id": "opp_1", "name": "First Man" })
	c.add_fight({ "result": "win", "opponent": "opp_1", "method": "TKO", "round": 2 })
	c.money = 500
	c.suspended_days = 14
	c.week_plan = "time_off"
	c.booked = { "opponent": "opp_1", "week": 9 }
	var saved: Dictionary = _through_json(c.to_dict())
	var back: Career = Career.from_dict(saved)
	assert_not_null(back, Career.load_error)
	_assert_same(_through_json(back.to_dict()), saved, "career")
	assert_eq(back.to_dict().dice, saved.dice, "the dice come back")
	assert_eq(back.week, 3)
	assert_eq(back.date_text(), c.date_text())
	assert_eq(back.record_text(false), "1-0-0")
	assert_eq(back.week_plan, "time_off")


func test_a_reloaded_career_carries_on_as_if_it_never_stopped() -> void:
	var straight: Career = _career(3)
	var reloaded: Career = _career(3)
	for i in 4:
		straight.run_week("all_out")
		reloaded.run_week("all_out")
	reloaded = Career.from_dict(_through_json(reloaded.to_dict()))
	for i in 12:
		straight.run_week("all_out")
		reloaded.run_week("all_out")
	assert_eq(reloaded.next_seed(), straight.next_seed(), "the career's dice carry on")
	# The same weeks, injuries and points as without the save.
	_assert_same(_through_json(reloaded.to_dict()), _through_json(straight.to_dict()), "career")


func test_the_same_seed_plays_the_same_career() -> void:
	var a: Career = _career(5)
	var b: Career = _career(5)
	for i in 8:
		a.run_week("all_out")
		b.run_week("all_out")
	assert_eq(_text(a.to_dict()), _text(b.to_dict()))
	assert_ne(_career(6).to_dict().dice, _career(5).to_dict().dice, "another seed rolls other dice")


func test_seeds_too_big_for_a_json_number_survive_the_save() -> void:
	var big: int = 9007199254740993  # 2^53 + 1: a JSON number would round it.
	var c: Career = _career(big)
	var back: Career = Career.from_dict(_through_json(c.to_dict()))
	assert_eq(back.career_seed, big)
	assert_eq(back.next_seed(), c.next_seed())


func test_a_save_from_a_newer_game_is_refused_with_the_reason() -> void:
	var data: Dictionary = _career().to_dict()
	data.version = Career.VERSION + 1
	assert_null(Career.from_dict(data))
	assert_string_contains(Career.load_error, "newer version")


func test_something_that_isnt_a_career_save_is_refused() -> void:
	assert_null(Career.from_dict({ "schema": "fighter@1", "name": "Kicker" }))
	assert_eq(Career.load_error, "not a career save")
	var no_trainee: Dictionary = _career().to_dict()
	no_trainee.erase("trainee")
	assert_null(Career.from_dict(no_trainee))
	assert_string_contains(Career.load_error, "trainee")


func test_the_load_screen_summary_says_who_when_and_how_he_is_doing() -> void:
	var s: Dictionary = _career().summary()
	assert_eq(s.name, "Wrestler")
	assert_eq(s.nickname, "The Hammer")
	assert_eq(s.age, 16)
	assert_eq(s.date, "Mon 4 Jan 2027")
	assert_eq(s.amateur_record, "0-0-0")
	assert_false(s.pro)


func test_a_week_says_what_happened_in_it() -> void:
	var c: Career = _career()
	c.week_plan = "time_off"
	c.trainee.injured_days = 5
	c.trainee.injury_area = "body"
	c.suspended_days = 3
	var report: Dictionary = c.run_week()
	var kinds: Array = report.events.map(func(e: Dictionary) -> String: return e.kind)
	assert_true(Career.HEALED in kinds, "healed")
	assert_true(Career.CLEARED in kinds, "suspension over")
	assert_eq(report.week, 0, "the week it happened in")
	for i in 50:
		c.run_week()
	report = c.run_week()
	assert_eq(c.age(), 17)
	assert_eq(report.events[0].kind, Career.BIRTHDAY)
	assert_eq(Career.event_text(report.events[0]), "Turns 17")


func test_advance_runs_until_something_happens() -> void:
	var c: Career = _career()
	c.week_plan = "time_off"
	c.trainee.injured_days = 10
	c.trainee.injury_area = "legs"
	var reports: Array[Dictionary] = c.advance()
	assert_eq(reports.size(), 2, "10 days out heals in the second week")
	assert_eq(reports[-1].events[0].kind, Career.HEALED)
	assert_eq(c.week, 2)
	c.offers.clear()
	c.next_offers_week = 1000  # No offers coming (D304).
	reports = c.advance()
	assert_eq(reports.size(), Career.ADVANCE_MAX_WEEKS, "with nothing coming up it stops after %d weeks" % Career.ADVANCE_MAX_WEEKS)
	c.booked = { "opponent": "opp_1", "week": c.week + 4 }
	assert_true(c.advance().is_empty(), "booked for a fight, the camp runs the weeks")


func test_advance_stops_the_first_week_training_wears_him_down() -> void:
	# At 18: a 16-year-old's school weeks (D314) leave too few sessions for a week all out to wear him down.
	var c: Career = Career.create(_fighter(18), 1, { "coach": "Sam" })
	var kinds := func(report: Dictionary) -> Array: return report.events.map(func(e: Dictionary) -> String: return e.kind)
	var hard: Dictionary = c.run_week("all_out")
	assert_gt(float(hard.fatigue_peak), TrainingCamp.FATIGUE_FREE, "a week all out takes him past the line")
	assert_true(Career.WORN_DOWN in kinds.call(hard), "the first hard week is news")
	assert_eq(Career.event_text({ "kind": Career.WORN_DOWN }), "Worn down from training")
	assert_false(Career.WORN_DOWN in kinds.call(c.run_week("all_out")), "the same again the next week isn't")
	var loaded: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_true(loaded.worn_last_week, "a save remembers it")
	assert_false(Career.WORN_DOWN in kinds.call(c.run_week("time_off")))
	assert_false(c.worn_last_week)
	assert_true(Career.WORN_DOWN in kinds.call(c.run_week("all_out")), "after an easy week it's news again")


func test_the_calendar_shows_what_is_coming() -> void:
	var c: Career = _career()
	c.trainee.injured_days = 10
	c.trainee.injury_area = "legs"
	c.suspended_days = 14
	c.booked = { "opponent": "opp_1", "week": 3 }
	var weeks: Array[Dictionary] = c.calendar(52)
	assert_eq(weeks.size(), 52)
	assert_eq(weeks[0].date, "Mon 4 Jan")
	assert_eq(weeks[1].date, "Mon 11 Jan")
	var kinds := func(i: int) -> Array: return weeks[i].events.map(func(e: Dictionary) -> String: return e.kind)
	assert_true(Career.HEALED in kinds.call(1), "10 days out: healed during the second week")
	assert_true(Career.CLEARED in kinds.call(1), "14 days' suspension: over during the second week")
	assert_true(Career.FIGHT_NIGHT in kinds.call(3))
	assert_true(Career.BIRTHDAY in kinds.call(51), "his birthday in the 52nd week")
	assert_eq(c.date_text(5, 1), "Sat 16 Jan 2027")


## The two are the same, numbers to within a billionth: a number read back from a JSON file can come back a last
## binary digit off (about 1e-16 of it), which no dice roll can tell apart.
func _assert_same(got: Variant, want: Variant, path: String = "") -> void:
	if want is Dictionary:
		assert_true(got is Dictionary and got.size() == want.size(), "%s has the same keys" % path)
		for key: Variant in want:
			_assert_same(got.get(key) if got is Dictionary else null, want[key], "%s.%s" % [path, key])
	elif want is Array:
		assert_true(got is Array and got.size() == want.size(), "%s has the same length" % path)
		for i in mini(want.size(), got.size() if got is Array else 0):
			_assert_same(got[i], want[i], "%s[%d]" % [path, i])
	elif want is float or want is int:
		assert_true((got is float or got is int) and absf(float(got) - float(want)) <= 1e-9 * maxf(1.0, absf(float(want))), "%s: %s vs %s" % [path, got, want])
	else:
		assert_eq(got, want, path)
