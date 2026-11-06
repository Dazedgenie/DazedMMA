extends GutTest
## The coaches you hire at your gym (sim/world/staff.gd, docs/03 §14.3, D443): who's looking for work each month, their
## levels from what they did as fighters, one coach a role, what each does to training and the weight cut, their wages
## each Monday and walking out unpaid, the members they bring, and the save.


func _career(money: int = 2000) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 18
	p.potential = 80
	var gym := { "kind": "mma_gym", "culture": "family", "place": "unit", "name": "Test Gym", "owner_name": "Frank Doyle",
		"owner": "Owns it.", "dues": 40, "members": 16, "members_start": 16, "rent": Gym.rent_for(16, 40) }
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym, "country": "England", "hometown": "Leeds" })
	c.gym_money = money
	c.next_offers_week = 1000
	return c


## Retires `count` of the world's men from his country whose style coaches something, and returns their ids.
func _retire(c: Career, count: int) -> Array:
	var w: World = c.world()
	var ids: Array = w.men.keys()
	ids.sort()
	var out: Array = []
	for id: String in ids:
		var m: Dictionary = w.men[id]
		if NameLibrary.shared().country_id_of(String(m.country)) != w.country_id or Staff.role_for_style(String(m.style)) == "":
			continue
		m.retired = maxi(0, c.week - 1)
		out.append(id)
		if out.size() >= count:
			break
	return out


func _coach(role: String, level: int = 1, personality: String = "patient") -> Dictionary:
	return { "id": "test_%s" % role, "name": "Joe %s" % role.capitalize(), "role": role, "level": level, "personality": personality,
		"country_id": "england", "age": 40, "line": "", "from": "" }


func test_every_role_and_personality_has_a_name_and_does_something() -> void:
	assert_eq(Staff.roles().keys(), ["striking", "wrestling", "bjj", "strength", "nutrition"])
	for id: String in Staff.roles():
		assert_ne(String(Staff.role(id).get("name", "")), "", id)
		assert_false(Staff.does_lines(_coach(id)).is_empty(), id)
	for id: String in Staff.personalities():
		assert_ne(String(Staff.personality(id).get("name", "")), "", id)
	assert_eq(Staff.role_for_style("boxer"), "striking")
	assert_eq(Staff.role_for_style("pressure_wrestler"), "wrestling")
	assert_eq(Staff.role_for_style("sambo"), "bjj")


func test_three_to_five_look_for_work_each_month_mostly_retired_fighters_from_home() -> void:
	var c: Career = _career()
	var retired: Array = _retire(c, 30)
	var list: Array = c.coaches_looking()
	assert_between(list.size(), Staff.LOOKING[0], Staff.LOOKING[1])
	var fighters: Array = list.filter(func(x: Dictionary) -> bool: return String(x.from) != "")
	var career: Array = list.filter(func(x: Dictionary) -> bool: return String(x.from) == "")
	assert_between(career.size(), Staff.CAREER_COACHES[0], Staff.CAREER_COACHES[1], "a career coach or two")
	assert_eq(fighters.size() + career.size(), list.size())
	for coach: Dictionary in fighters:
		assert_true(String(coach.from) in retired, "a retired man")
		assert_eq(String(coach.role), Staff.role_for_style(String(c.world().man(String(coach.from)).style)), "his style's role")
	for coach: Dictionary in list:
		assert_between(int(coach.level), 1, Staff.LEVELS)
		assert_true(Staff.personalities().has(String(coach.personality)))
	assert_eq(c.coaches_looking(), list, "the same men all month")
	assert_eq(Staff.looking(c.world(), c.gym, c.career_seed, Staff.month_key(c.date()), c.week), list, "seeded")


func test_a_champion_coaches_at_level_three_a_national_pro_at_two_the_rest_at_one() -> void:
	var c: Career = _career()
	var ids: Array = _retire(c, 3)
	var w: World = c.world()
	var rng := RandomNumberGenerator.new()
	w.reigns[ids[0]] = [[String(w.promotions[0].id) + ":" + String(w.man(ids[0]).division), 0, 10, 2, "lost"]]
	w.man(ids[1]).tier = "national"
	w.man(ids[2]).tier = "local"
	var champ: Dictionary = Staff.from_fighter(w, w.man(ids[0]), c.week, rng)
	assert_eq(int(champ.level), 3)
	assert_string_contains(String(champ.line), "Former")
	assert_eq(int(Staff.from_fighter(w, w.man(ids[1]), c.week, rng).level), 2)
	assert_eq(int(Staff.from_fighter(w, w.man(ids[2]), c.week, rng).level), 1)


func test_hiring_takes_him_off_the_list_and_you_get_one_coach_a_role() -> void:
	var c: Career = _career()
	c.gym.looking = [_coach("striking"), _coach("striking", 2), _coach("bjj")]
	c.gym.looking[1].id = "other"
	c.gym.looking_at = Staff.month_key(c.date())
	c.gym.repute = { "score": GymRepute.LEVELS[GymRepute.TOWN] }  # Known in town: a level 2 coach comes (D446).
	assert_eq(c.hire_coach(0), "")
	assert_eq(Staff.coaches(c.gym).size(), 1)
	assert_eq((c.gym.looking as Array).size(), 2, "off the list")
	assert_string_contains(c.hire_coach(0), "let him go first", "one striking coach")
	assert_eq(c.hire_coach(1), "")
	assert_eq(String(c.let_go_coach("striking").role), "striking")
	assert_eq(c.hire_coach(0), "", "room for a striking coach again")
	assert_eq(Staff.wages(c.gym), Staff.WAGES[1] + Staff.WAGES[0])


func test_a_coach_speeds_up_his_groups_stats_only_and_a_hard_one_more() -> void:
	var c: Career = _career()
	var boxing: float = c.trainee.learning("boxing")
	var takedowns: float = c.trainee.learning("takedowns")
	c.gym.coaches = [_coach("striking", 2)]
	assert_almost_eq(c.trainee.learning("boxing"), boxing * 1.1, 0.0001, "level 2: 10% faster")
	assert_almost_eq(c.trainee.learning("takedowns"), takedowns, 0.0001, "not his group")
	c.gym.coaches = [_coach("striking", 3, "hard")]
	assert_almost_eq(Staff.xp_share(c.gym, "Striking"), 1.2, 0.0001, "15% and a hard man's 5%")
	c.gym.coaches = [_coach("strength", 1)]
	assert_almost_eq(Staff.xp_share(c.gym, "Physical"), 1.05, 0.0001)


func test_personalities_change_injuries_and_skips() -> void:
	var c: Career = _career()
	var injury: float = Gym.injury_share(c.gym, "sparring")
	var skips: float = Gym.skip_share(c.gym)
	c.gym.coaches = [_coach("striking", 1, "hard")]
	assert_gt(Gym.injury_share(c.gym, "sparring"), injury)
	c.gym.coaches = [_coach("striking", 1, "patient")]
	assert_lt(Gym.injury_share(c.gym, "sparring"), injury)
	c.gym.coaches = [_coach("striking", 1, "fiery")]
	assert_lt(Gym.skip_share(c.gym), skips)


func test_a_nutritionist_makes_the_cut_cost_less() -> void:
	var plain: Dictionary = WeightCut.side(78.0, 70.3, WeightCut.HARD, false, 1.0, 0.0)
	var gym := { "coaches": [_coach("nutrition", 2)] }
	assert_almost_eq(Staff.cut_share(gym), 0.6, 0.0001, "level 2: 40% less")
	var eased: Dictionary = WeightCut.side(78.0, 70.3, WeightCut.HARD, false, 1.0, 0.0, Staff.cut_share(gym))
	assert_lt(float(eased.tank_cost), float(plain.tank_cost))
	assert_lt(float(eased.chin_cost), float(plain.chin_cost))
	assert_lt(float(eased.miss_chance), float(plain.miss_chance))
	assert_eq(float(eased.night_kg), float(plain.night_kg), "the same weight")


func test_wages_go_out_each_monday_and_an_unpaid_coach_walks_after_two_weeks() -> void:
	var c: Career = _career(200)
	c.gym.dues = 0  # No month's money to muddle the wages.
	c.gym.rent = 0
	c.gym.coaches = [_coach("striking", 3)]
	c.run_week("time_off")
	assert_eq(int(c.coach_week.paid), Staff.WAGES[2])
	assert_eq(c.gym_money, 200 - Staff.WAGES[2], "a week's wage")
	c.gym_money = 10
	var events: Array = []
	for i in Staff.UNPAID_WEEKS + 1:
		events.append_array(c.run_week("time_off").events)
	var kinds: Array = events.map(func(e: Dictionary) -> String: return String(e.kind))
	assert_eq(kinds.count(Career.COACH_UNPAID), Staff.UNPAID_WEEKS, "warned each week")
	assert_eq(kinds.count(Career.COACH_LEFT), 1)
	assert_true(Staff.coaches(c.gym).is_empty(), "gone")
	assert_string_contains(Career.event_text(events.filter(func(e: Dictionary) -> bool: return String(e.kind) == Career.COACH_LEFT)[0]), "walked out")


func test_a_paid_week_clears_what_he_was_owed() -> void:
	var gym := { "coaches": [_coach("striking", 1)] }
	assert_eq(int(Staff.pay_week(gym, 0).paid), 0)
	assert_eq(int(gym.coaches[0].unpaid), 1)
	assert_eq(int(Staff.pay_week(gym, 100).paid), Staff.WAGES[0])
	assert_eq(int(gym.coaches[0].unpaid), 0)


func test_each_coach_level_brings_a_member() -> void:
	var c: Career = _career()
	var before: int = Gym.members_target(c.gym, 0)
	c.gym.coaches = [_coach("striking", 2), _coach("nutrition", 1)]
	assert_eq(Gym.members_target(c.gym, 0), mini(before + 3 * Staff.MEMBERS_PER_LEVEL, Gym.cap(c.gym)))


func test_coaches_and_who_is_looking_save_and_load() -> void:
	var c: Career = _career()
	c.gym.coaches = [_coach("bjj", 2)]
	c.gym.coaches[0].unpaid = 1
	c.gym.coaches[0].since = 3
	c.gym.looking = [_coach("wrestling")]
	c.gym.looking_at = Staff.month_key(c.date())
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(Staff.coaches(back.gym).size(), 1)
	assert_eq(typeof(back.gym.coaches[0].level), TYPE_INT)
	assert_eq(int(back.gym.coaches[0].unpaid), 1)
	assert_eq(String(back.gym.looking[0].role), "wrestling")
	assert_eq(back.coaches_looking().size(), 1, "the same list this month")
	assert_eq(Staff.xp_share(back.gym, "Grappling"), Staff.xp_share(c.gym, "Grappling"))


func test_a_gym_saved_before_coaches_has_none_and_trains_as_before() -> void:
	var c: Career = _career()
	var d: Dictionary = c.to_dict()
	(d.gym as Dictionary).erase("coaches")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(Staff.coaches(back.gym).is_empty())
	assert_eq(Staff.xp_share(back.gym, "Striking"), 1.0)
	assert_eq(Staff.wages(back.gym), 0)
