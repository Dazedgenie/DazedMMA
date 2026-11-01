extends GutTest
## Your gym (sim/world/gym.gd, docs/03 §11.3, D313): three gyms in his hometown, what the one you pick does to his
## training, and its monthly fee.


func _career(gym: Dictionary = {}, money: int = 500) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 16
	p.potential = 80
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym })
	c.money = money
	c.next_offers_week = 1000  # No fight offers to get in the way.
	return c


func _gym(kind: String, culture: String = "family", fee: int = 50) -> Dictionary:
	return { "kind": kind, "culture": culture, "name": "Test Gym", "owner_name": "Frank Doyle", "owner": "Owns it.", "fee": fee }


func test_a_new_career_is_offered_three_different_gyms_and_the_first_suits_him() -> void:
	var offers: Array = Gym.offers("Leeds", "england", "boxing_gym_kid", 7)
	assert_eq(offers.size(), Gym.OFFERS)
	var kinds: Array = offers.map(func(g: Dictionary) -> String: return String(g.kind))
	for k: String in kinds:
		assert_eq(kinds.count(k), 1, "three different kinds")
	assert_true("boxing_gym_kid" in Gym.kind(String(offers[0].kind)).backgrounds, "the first suits a boxing gym kid")
	for g: Dictionary in offers:
		assert_ne(String(g.name), "")
		assert_false(String(g.name).contains("{"), "the name's filled in")
		assert_true(Gym.cultures().has(String(g.culture)))
		var fee: Array = Gym.kind(String(g.kind)).fee
		assert_between(int(g.fee), int(fee[0]), int(fee[1]))
	assert_eq(Gym.offers("Leeds", "england", "boxing_gym_kid", 7), offers, "seeded by the career")


func test_a_gym_trains_its_own_kind_of_session_faster() -> void:
	var boxing: Dictionary = _gym("boxing_gym")
	assert_gt(Gym.xp_share(boxing, "striking"), 1.0)
	assert_lt(Gym.xp_share(boxing, "grappling"), 1.0)
	assert_eq(Gym.xp_share({}, "striking"), 1.0, "no gym, no change")
	assert_gt(Gym.xp_share(_gym("mma_gym", "hard_sparring"), "sparring"), Gym.xp_share(_gym("mma_gym", "family"), "sparring"), "hard sparring teaches more")
	var plan: Dictionary = TrainingLibrary.shared().plan("striker")
	var at_none: Dictionary = _career().trainee.forecast(plan)
	var at_boxing: Dictionary = _career(boxing).trainee.forecast(plan)
	assert_gt(float(at_boxing.gains.get("boxing", 0.0)), float(at_none.gains.get("boxing", 0.0)), "his boxing grows faster at a boxing gym")


func test_the_culture_changes_skips_and_injuries() -> void:
	assert_lt(Gym.skip_share(_gym("boxing_gym", "family")), 1.0)
	assert_gt(Gym.skip_share(_gym("boxing_gym", "party")), 1.0)
	assert_gt(Gym.injury_share(_gym("boxing_gym", "hard_sparring")), 1.0)
	var calm: Career = _career(_gym("boxing_gym", "family"))
	var rough: Career = _career(_gym("boxing_gym", "hard_sparring"))
	var sparring: Dictionary = TrainingLibrary.shared().session("hard_sparring")
	assert_gt(rough.trainee.injury_chance(sparring), calm.trainee.injury_chance(sparring))


func test_the_fee_comes_out_of_his_savings_on_the_first_monday_of_each_month() -> void:
	var c: Career = _career(_gym("boxing_gym", "family", 50), 120)
	var paid: Array = []
	for i in 9:
		paid.append(c.run_week("time_off").gym_fee)
	# Week 0 is Mon 4 Jan 2027; Mon 1 Feb is week 4 and Mon 1 Mar week 8.
	assert_eq(paid, [0, 0, 0, 50, 0, 0, 0, 50, 0])
	assert_eq(c.money, 20)
	var april: Dictionary = {}
	for i in 4:
		april = c.run_week("time_off")
	assert_eq(c.money, 0, "as much as he has, never below nothing")
	assert_eq(c.gym_owed, 30, "the rest he owes")
	assert_eq(april.events.map(func(e: Dictionary) -> String: return String(e.kind)), [Career.GYM_SHIFTS], "the owner offers him shifts")
	var shifts: Dictionary = c.run_week("time_off")
	assert_eq(int(shifts.gym_worked), 30, "a Saturday's shifts pay it off")
	assert_eq(c.gym_owed, 0)
	assert_eq(_career({}, 120).end_week(), 0, "no gym, no fee")


func test_working_off_the_fee_takes_his_saturday() -> void:
	var plan: Dictionary = TrainingLibrary.shared().plan("striker")
	var shifts: Dictionary = Gym.with_shifts(plan)
	assert_eq(shifts.days[Gym.SHIFT_DAY], [Gym.SHIFT_SESSION, Gym.SHIFT_SESSION])
	assert_ne(plan.days[Gym.SHIFT_DAY], shifts.days[Gym.SHIFT_DAY], "a copy: the plan itself doesn't change")
	assert_eq(Gym.shift_week_pay(), Gym.SHIFT_PAY * 2)
	var c: Career = _career(_gym("boxing_gym", "family", 50), 0)
	c.gym_owed = 100
	assert_string_contains(CareerHub.week_text(c), "Owes the gym $100")
	var report: Dictionary = c.run_week("striker")
	assert_eq(int(report.gym_worked), Gym.shift_week_pay())
	assert_eq(c.gym_owed, 100 - Gym.shift_week_pay())
	assert_string_contains(CareerHub.last_text(c, [report]), "Worked $%d off at the gym." % Gym.shift_week_pay())
	assert_eq(Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict()))).gym_owed, c.gym_owed, "saved")


func test_the_gym_saves_with_the_career() -> void:
	var c: Career = _career(_gym("bjj_academy", "party", 75))
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.gym, c.gym)
	assert_eq(back.trainee.gym, c.gym, "and trains him the same after loading")
	var old: Dictionary = c.to_dict()
	old.erase("gym")
	assert_true(Career.from_dict(JSON.parse_string(JSON.stringify(old))).gym.is_empty(), "a career from before D313 has none")


func test_the_hub_says_where_he_trains_and_the_walk_in_names_him() -> void:
	var c: Career = _career(_gym("muay_thai_camp", "hard_sparring", 60))
	assert_string_contains(CareerHub.fighter_card_text(c), "Trains at Test Gym (Muay Thai camp · Hard sparring)")
	assert_string_contains(CareerHub.week_text(c), "the gym is $60 a month")
	var walk_in: String = GymScreen.walk_in_text(c.gym, { "name": "Danny Hill", "background": "street_kid",
		"people": [{ "role": "Dad", "name": "Gary Hill" }] }, "Sam Reed")
	assert_string_contains(walk_in, "\"I'm Danny Hill,\"")
	assert_string_contains(walk_in, "His dad, Gary Hill, told him to come here.")
	assert_string_contains(walk_in, "You're Sam Reed")
