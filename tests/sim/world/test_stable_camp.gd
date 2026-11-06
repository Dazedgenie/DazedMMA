extends GutTest
## A stable man's camp (sim/world/stable.gd and Career, docs/03 §14.7, D451): opened for his booked fight, a week at a
## time with the calendar, what it adds staying on the world man, a week you don't run run on the plan you left, his
## fight from it, the doctor calling it off, saved, and gone after the fight.


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


## A signed amateur booked for a fight (his first offer taken): his id.
func _booked(c: Career) -> String:
	for m: Dictionary in c.stable_prospects():
		if not bool(m.get("pro", false)) and not Lads.at_gym(c.gym, String(m.id)):
			assert_eq(Stable.offer(c.world(), c.gym, m, c.week, 0.0), "")
			var id: String = String(m.id)
			for i in 30:
				if not Stable.offers_of(Stable.entry(c.gym, id)).is_empty():
					break
				c.end_week()
			assert_true(c.take_stable_offer(id, 0), "booked")
			return id
	return ""


func test_opening_his_camp_makes_one_from_the_world_man_and_he_trains_in_it_not_on_his_focus() -> void:
	var c: Career = _career()
	var id: String = _booked(c)
	assert_true(Stable.camp_of(Stable.entry(c.gym, id)).is_empty(), "not opened yet")
	assert_true(Stable.trained(c.gym).has(id), "on his focus")
	var t: TrainingCamp = c.stable_camp(id)
	assert_not_null(t)
	assert_eq(t.stat("boxing"), float(c.world().profile(id, c.week).stats.boxing), "him as he is")
	assert_eq(t.gym, c.gym, "your gym's rooms")
	assert_false(Stable.camp_of(Stable.entry(c.gym, id)).is_empty(), "kept on his entry")
	assert_false(Stable.trained(c.gym).has(id), "his camp trains him now")
	assert_same(c.stable_camp(id), t, "the same camp each time")
	assert_eq(Stable.camp_weeks_left(Stable.entry(c.gym, id), c.week), int(Stable.booking(Stable.entry(c.gym, id)).week) - c.week + 1)


func test_a_week_run_by_hand_stays_on_the_world_man() -> void:
	var c: Career = _career()
	var id: String = _booked(c)
	var t: TrainingCamp = c.stable_camp(id)
	var before: float = c.world().average(c.world().man(id))
	var report: Dictionary = t.run_plan(TrainingLibrary.shared().plan(Stable.CAMP_PLAN))
	c.stable_camp_week(id, report)
	assert_true(c.stable_camp_ran(id))
	assert_gt(c.world().average(c.world().man(id)), before, "his gains are the world man's")
	var p: Dictionary = c.world().profile(id, c.week)
	for stat: String in ["boxing", "takedowns", "cardio"]:
		assert_almost_eq(float(p.stats[stat]), t.stat(stat), 0.51, stat)


func test_a_week_you_dont_run_runs_on_the_plan_you_left() -> void:
	var c: Career = _career()
	var id: String = _booked(c)
	var t: TrainingCamp = c.stable_camp(id)
	var plan: Dictionary = TrainingLibrary.shared().plan(Stable.CAMP_PLAN)
	c.set_stable_camp_plan(id, plan)
	var fatigue_before: float = t.fatigue
	var week: int = c.week
	c.end_week()
	var camp: Dictionary = Stable.camp_of(Stable.entry(c.gym, id))
	assert_eq(int(camp.ran), week, "last week ran")
	assert_eq(String(camp.plan.get("id", "")), String(plan.id))
	assert_ne(float(camp.snap.fatigue), fatigue_before, "and did something")
	assert_false(c.stable_camp_ran(id), "this week's still to run")


func test_he_fights_as_his_camp_leaves_him() -> void:
	var c: Career = _career()
	var id: String = _booked(c)
	var b: Dictionary = Stable.booking(Stable.entry(c.gym, id))
	c.stable_camp(id)
	c.set_stable_camp_plan(id, TrainingLibrary.shared().plan(Stable.CAMP_PLAN))
	while c.week < int(b.week):
		c.end_week()
	var f: Dictionary = c.stable_fight(id)
	assert_false(f.is_empty())
	assert_true(c.stable_camp_ran(id), "fight week ran on his plan first")
	assert_true(f.red.has("condition"), "fight night's gas tank")
	assert_eq(String(f.red.id), id + "_camp")
	assert_eq(String(f.red.name), String(Stable.entry(c.gym, id).name))
	c.finish_stable_fight(id, "win", "decision", 3, 7)
	assert_true(Stable.camp_of(Stable.entry(c.gym, id)).is_empty(), "the camp's over")
	assert_null(c.stable_camp(id), "nothing booked now")


func test_the_doctor_calls_it_off_after_a_camp_that_hurt_him() -> void:
	var c: Career = _career()
	var id: String = _booked(c)
	var b: Dictionary = Stable.booking(Stable.entry(c.gym, id))
	var t: TrainingCamp = c.stable_camp(id)
	while c.week < int(b.week):
		c.end_week()
	t = c.stable_camp(id)
	c.stable_camp_week(id, t.run_plan(TrainingLibrary.shared().plan(Stable.CAMP_PLAN), {}, true))
	t.injured_days = 30
	t.injury_area = "legs"
	c.stable_camp_week(id, {})
	assert_false(c.stable_cleared(id))
	assert_true(c.stable_fight(id).is_empty(), "no fight")
	assert_true(Stable.booking(Stable.entry(c.gym, id)).is_empty(), "it's off")
	assert_gte(int(c.world().man(id).out_until), c.week + 4, "out while it heals")
	var kinds: Array = c.stable_news.map(func(n: Dictionary) -> String: return String(n.kind))
	assert_true(Career.STABLE_CALLED_OFF in kinds, str(kinds))


func test_left_alone_a_hurt_man_isnt_put_in_the_fight() -> void:
	var c: Career = _career()
	var id: String = _booked(c)
	var b: Dictionary = Stable.booking(Stable.entry(c.gym, id))
	c.stable_camp(id)
	while c.week < int(b.week):
		c.end_week()
	var t: TrainingCamp = c.stable_camp(id)
	c.stable_camp_week(id, t.run_plan(TrainingLibrary.shared().plan(Stable.CAMP_PLAN), {}, true))
	t.injured_days = 30
	c.stable_camp_week(id, {})
	var fights: int = (c.world().man(id).history as Array).size()
	c.end_week()
	assert_eq((c.world().man(id).history as Array).size(), fights, "not fought")
	assert_true(Stable.booking(Stable.entry(c.gym, id)).is_empty())


func test_turning_the_fight_down_ends_his_camp() -> void:
	var c: Career = _career()
	var id: String = _booked(c)
	c.stable_camp(id)
	assert_true(c.turn_down_stable_fight(id))
	assert_true(Stable.camp_of(Stable.entry(c.gym, id)).is_empty())
	assert_true(Stable.trained(c.gym).has(id), "back on his focus")


func test_his_camp_saves_and_loads_mid_camp() -> void:
	var c: Career = _career()
	var id: String = _booked(c)
	var t: TrainingCamp = c.stable_camp(id)
	c.stable_camp_week(id, t.run_plan(TrainingLibrary.shared().plan(Stable.CAMP_PLAN)))
	c.set_stable_camp_plan(id, TrainingLibrary.shared().plan(Stable.CAMP_PLAN))
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var camp: Dictionary = Stable.camp_of(Stable.entry(back.gym, id))
	assert_eq(typeof(camp.ran), TYPE_INT)
	assert_true(back.stable_camp_ran(id))
	var again: TrainingCamp = back.stable_camp(id)
	assert_almost_eq(again.fatigue, t.fatigue, 0.001)
	assert_almost_eq(again.stat("cardio"), t.stat("cardio"), 0.001)
	Stable.month(back.world(), back.gym, back.week, 100)
	assert_false(Stable.camp_of(Stable.entry(back.gym, id)).is_empty(), "the month's refresh keeps it")


func test_the_news_reads_plainly() -> void:
	assert_eq(Stable.news_text({ "kind": Stable.CALLED_OFF, "name": "Jake Moss", "opponent": "Tom Reid" }),
		"Jake Moss's fight with Tom Reid is off: the doctor won't clear him after his camp")
	assert_true(Career.STABLE_CALLED_OFF in Career.JUST_NEWS)
