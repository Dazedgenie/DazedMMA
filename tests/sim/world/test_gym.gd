extends GutTest
## Your gym (sim/world/gym.gd, docs/03 §11.3 and §14.1, D313, D441): three run-down places in his hometown, what the one
## you open does to his training, and its money: members' dues, rent and a cut of his purses.


func _career(gym: Dictionary = {}, money: int = 500) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 16
	p.potential = 80
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym })
	c.money = money
	c.next_offers_week = 1000  # No fight offers to get in the way.
	return c


func _gym(kind: String, culture: String = "family", dues: int = 40) -> Dictionary:
	return { "kind": kind, "culture": culture, "place": "unit", "name": "Test Gym", "owner_name": "Frank Doyle",
		"owner": "Owns it.", "dues": dues, "members": 16, "members_start": 16, "rent": Gym.rent_for(16, dues) }


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
		assert_between(int(g.dues), int(fee[0]), int(fee[1]))
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


func test_each_place_on_offer_is_a_different_run_down_place_with_members_and_rent() -> void:
	var offers: Array = Gym.offers("Leeds", "england", "farm_kid", 11)
	var places: Array = offers.map(func(g: Dictionary) -> String: return String(g.place))
	places.sort()
	var all: Array = Gym.places().keys()
	all.sort()
	assert_eq(places, all, "a garage, a unit and a hall, one of each")
	for g: Dictionary in offers:
		var span: Array = Gym.place(String(g.place)).members
		assert_between(int(g.members), int(span[0]), int(span[1]))
		assert_eq(int(g.members_start), int(g.members))
		var fee: Array = Gym.kind(String(g.kind)).fee
		assert_between(int(g.dues), int(fee[0]), int(fee[1]), "a member pays the kind's monthly fee")
		assert_eq(int(g.rent), Gym.rent_for(int(g.members), int(g.dues)))
		assert_gt(Gym.month_net(g), 0, "tight: the first members just cover the rent")
		assert_lt(Gym.month_net(g), Gym.dues_in(g) / 4, "and not much more")


func test_the_gym_has_its_own_money_apart_from_his_savings() -> void:
	var c: Career = _career(_gym("boxing_gym"), 120)
	assert_eq(c.gym_money, Gym.START_MONEY, "what you put in to open it")
	assert_eq(c.money, 120, "his savings are his")
	assert_eq(_career({}, 120).gym_money, 0, "no gym, no gym money")


func test_members_pay_and_the_rent_goes_out_on_the_first_monday_of_each_month() -> void:
	var c: Career = _career(_gym("boxing_gym"), 120)
	var months: Array = []
	var money: Array = []
	for i in 9:
		var report: Dictionary = c.run_week("time_off")
		months.append(not (report.gym_month as Dictionary).is_empty())
		money.append(c.gym_money)
	# Week 0 is Mon 4 Jan 2027; Mon 1 Feb is week 4 and Mon 1 Mar week 8.
	assert_eq(months, [false, false, false, true, false, false, false, true, false])
	var g: Dictionary = _gym("boxing_gym")
	assert_eq(money[3], Gym.START_MONEY + Gym.dues_in(g) - int(g.rent), "February: 16 members' dues less the rent")
	assert_eq(c.money, 120, "he pays nothing: it's your gym")
	assert_eq(int(c.gym_last_month.week), c.week - 1, "the last month kept for the hub")
	assert_eq(_career({}, 120).end_week(), {}, "no gym, no month")


func test_members_come_with_the_gyms_name_up_to_what_the_place_holds() -> void:
	var g: Dictionary = _gym("boxing_gym")
	var dice := RandomNumberGenerator.new()
	assert_eq(Gym.members_target(g, 0), 16)
	assert_eq(Gym.members_target(g, 4), 16 + roundi(4 * GymRepute.MEMBERS_PER_POINT), "its name brings members (D446)")
	assert_eq(Gym.members_target(g, 100), int(Gym.place("unit").cap), "never more than the place holds")
	var grown: Array = []
	for i in 12:
		grown.append(int(Gym.month(g, 10, dice).members))
	assert_gt(grown[-1], 16, "members join as its name grows")
	assert_lte(grown.max(), Gym.members_target(g, 10))
	var quiet: Dictionary = _gym("boxing_gym")
	for i in 12:
		Gym.month(quiet, 0, dice)
	assert_lte(int(quiet.members), 16, "with no name they only drift off")


func test_the_gym_takes_its_cut_of_every_purse_he_is_paid() -> void:
	assert_eq(Gym.purse_cut(2000), 300, "15% of a $2,000 purse")
	assert_eq(Gym.purse_cut(0), 0)
	var c: Career = _career(_gym("boxing_gym"), 0)
	var fight: Dictionary = { "result": "win" }
	c._pay(fight, 2000)
	assert_eq(c.money, 1700, "his 85%")
	assert_eq(c.gym_money, Gym.START_MONEY + 300, "the gym's 15%")
	assert_eq(int(fight.gym_cut), 300, "on the fight's entry")
	fight.purse = 2000
	var rows: Array = FightResultCard.meaning_rows(c.standing(), c.standing(), fight, "")
	var purse: Array = rows.filter(func(r: Array) -> bool: return String(r[0]) == "Purse")
	assert_string_contains(String(purse[0][1]), "the gym's 15%: $300")
	var none: Career = _career({}, 0)
	none._pay({}, 2000)
	assert_eq(none.money, 2000, "a career with no gym keeps it all")


func test_behind_on_the_rent_is_news() -> void:
	var c: Career = _career(_gym("boxing_gym"), 0)
	c.gym_money = 10
	c.gym.members = 1
	var events: Array = []
	for i in 4:
		for e: Dictionary in c.run_week("time_off").events:
			events.append(String(e.kind))
	assert_lt(c.gym_money, 0)
	assert_true(Career.GYM_BEHIND in events, "Advance stops on it")
	assert_string_contains(CareerHub.week_text(c), "behind on the rent")


func test_a_save_from_when_he_paid_a_fee_becomes_your_gym() -> void:
	var c: Career = _career(_gym("bjj_academy"))
	var old: Dictionary = c.to_dict()
	old.gym = { "kind": "bjj_academy", "culture": "party", "name": "Old Gym", "owner_name": "Frank Doyle", "owner": "Owns it.", "fee": 75 }
	old.erase("gym_money")
	old.erase("gym_last_month")
	old.gym_owed = 30
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_eq(String(back.gym.place), Gym.OLD_SAVE_PLACE)
	assert_eq(int(back.gym.dues), 75, "his fee is what a member pays")
	assert_eq(int(back.gym.members), Gym.OLD_SAVE_MEMBERS)
	assert_false(back.gym.has("fee"))
	assert_eq(back.gym_money, Gym.START_MONEY)
	assert_eq(back.trainee.gym, back.gym, "trains him as before")


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
	assert_string_contains(CareerHub.fighter_card_text(c), "Trains at your gym, Test Gym (Muay Thai camp · Hard sparring)")
	assert_string_contains(CareerHub.week_text(c), "Your gym: $%d · A unit on the estate · 16 members at $60 a month" % Gym.START_MONEY)
	var walk_in: String = GymScreen.walk_in_text(c.gym, { "name": "Danny Hill", "background": "street_kid",
		"people": [{ "role": "Dad", "name": "Gary Hill" }] }, "Sam Reed")
	assert_string_contains(walk_in, "\"I'm Danny Hill,\"")
	assert_string_contains(walk_in, "His dad, Gary Hill, told him to come here.")
	assert_string_contains(walk_in, "You're Sam Reed")
