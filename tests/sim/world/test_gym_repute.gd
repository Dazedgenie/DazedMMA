extends GutTest
## Your gym's name (sim/world/gym_repute.gd, docs/03 §14.8, D446): one number shown as a word and a bar, made from
## the gym's fights, its ranked men and belts, its rooms and coaches and its trouble, fading with time, and what it
## opens: members, who'll sign, which coaches come, lads walking in, and the news when it moves.


func _career(members: int = 16) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 18
	p.potential = 80
	var gym := { "kind": "mma_gym", "culture": "family", "place": "unit", "name": "Test Gym", "owner_name": "Frank Doyle",
		"owner": "Owns it.", "dues": 40, "members": members, "members_start": members, "rent": Gym.rent_for(members, 40) }
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym, "country": "England", "hometown": "Leeds" })
	c.gym_money = 2000
	c.next_offers_week = 1000
	return c


func _win(c: Career, method: String = "decision") -> void:
	c.add_opponent({ "id": "opp_%d" % c.fights.size(), "name": "Tom Reid" })
	c.add_fight({ "result": "win", "method": method, "opponent": "opp_%d" % c.fights.size(), "pro": false })


func test_the_levels_read_as_words_with_a_bar_to_the_next() -> void:
	assert_eq(GymRepute.LEVEL_NAMES.size(), GymRepute.LEVELS.size())
	assert_eq(GymRepute.level_of(0.0), 0)
	assert_eq(GymRepute.level_name(GymRepute.level_of(GymRepute.LEVELS[GymRepute.TOWN])), "Known in town")
	assert_eq(GymRepute.level_name(GymRepute.level_of(GymRepute.LEVELS[GymRepute.WORLD] + 5.0)), "World famous")
	assert_almost_eq(GymRepute.to_next(20.0), (20.0 - 10.0) / (30.0 - 10.0), 0.001, "halfway from town to the region")
	assert_eq(GymRepute.to_next(95.0), 1.0, "full at the top")
	var g := { "repute": { "score": 14.0 } }
	assert_eq(GymRepute.line(g), "Known in town · 14 of 30 to Known in the region")


func test_his_wins_make_the_name_and_a_pro_win_up_the_ladder_counts_more() -> void:
	var c: Career = _career()
	assert_eq(c.refresh_repute(), 0.0, "a new gym is unknown")
	for i in 3:
		_win(c)
	assert_almost_eq(GymRepute.score(c.gym), 3.0 * GymRepute.WIN_AMATEUR, 0.01, "three amateur wins")
	var regional: float = GymRepute.fight_points("win", "decision", true, Promotions.REGIONAL)
	assert_gt(GymRepute.fight_points("win", "decision", true, Promotions.MAJOR), regional, "the world organisation counts most")
	assert_gt(GymRepute.fight_points("win", "ko", true, Promotions.REGIONAL), regional, "a finish counts more")
	assert_gt(GymRepute.fight_points("win", "decision", true, Promotions.REGIONAL, true), regional, "a belt won more still")
	assert_lt(GymRepute.fight_points("loss", "decision", true, Promotions.REGIONAL), 0.0, "a pro loss takes a little")
	assert_eq(GymRepute.fight_points("loss", "ko", false, -1), 0.0, "an amateur loss nothing")


func test_it_fades_by_half_every_two_years() -> void:
	var c: Career = _career()
	for i in 4:
		_win(c)
	var now: float = c.refresh_repute()
	c.week += int(GymRepute.HALF_LIFE_WEEKS)
	assert_almost_eq(c.refresh_repute(), now / 2.0, 0.01)


func test_rooms_and_coaches_add_a_little() -> void:
	var c: Career = _career()
	c.gym.rooms[c.gym.rooms.keys()[0]] = int(c.gym.rooms[c.gym.rooms.keys()[0]]) + 2
	c.gym.coaches = [{ "id": "x", "name": "Joe", "role": "striking", "level": 2, "personality": "patient" }]
	assert_almost_eq(c.refresh_repute(), 2.0 * GymRepute.PER_ROOM_LEVEL + 2.0 * GymRepute.PER_COACH_LEVEL, 0.01)
	assert_eq(GymRepute.fame(c.gym), 0.0, "they bring their own members, not more through the name")


func test_trouble_takes_it_down_and_fades_too() -> void:
	var c: Career = _career()
	for i in 10:
		_win(c)
	var before: float = c.refresh_repute()
	GymRepute.mark(c.gym, c.week, -GymRepute.COACH_WALKED, "walked")
	assert_almost_eq(c.refresh_repute(), before - GymRepute.COACH_WALKED, 0.01)
	assert_lt(float(c.gym.repute.parts.trouble), 0.0, "shown as trouble")
	c.gym_money = -5000
	for i in 6:
		c.end_week()  # A month starts behind on the rent.
	var marks: Array = (c.gym.repute_marks as Array).map(func(m: Dictionary) -> String: return String(m.why))
	assert_true("rent" in marks, str(marks))


func test_a_coach_walking_out_unpaid_marks_it() -> void:
	var c: Career = _career()
	c.gym.coaches = [{ "id": "x", "name": "Joe", "role": "striking", "level": 1, "personality": "patient", "unpaid": Staff.UNPAID_WEEKS }]
	c.gym_money = -500
	c.end_week()
	var marks: Array = (c.gym.get("repute_marks", []) as Array).map(func(m: Dictionary) -> String: return String(m.why))
	assert_true("walked" in marks, str(marks))


func test_members_follow_the_name() -> void:
	var g: Dictionary = _career().gym
	var start: int = Gym.members_target(g, 0)
	g.repute = { "score": 10.0, "parts": { "fights": 10.0 } }
	assert_eq(Gym.members_target(g, GymRepute.fame(g)), mini(start + roundi(10.0 * GymRepute.MEMBERS_PER_POINT), Gym.cap(g)))


func test_a_bigger_name_signs_better_men_more_often() -> void:
	var c: Career = _career(80)
	assert_false("national" in Stable.signing_tiers(c.gym), "an unknown gym: no national pros")
	var amateur := { "id": "a", "tier": "amateur" }
	var plain: float = Stable.yes_chance(c.gym, amateur)
	c.gym.repute = { "score": GymRepute.LEVELS[GymRepute.NATIONAL] }
	assert_true("national" in Stable.signing_tiers(c.gym), "known nationally")
	assert_false("world" in Stable.signing_tiers(c.gym))
	assert_gt(Stable.yes_chance(c.gym, amateur), plain, "likelier to say yes")
	var w: World = c.world()
	var national: Array = Stable.prospects(w, c.gym, c.week).filter(func(m: Dictionary) -> bool: return String(m.get("tier", "")) == "national")
	c.gym.repute = { "score": 0.0 }
	var none: Array = Stable.prospects(w, c.gym, c.week).filter(func(m: Dictionary) -> bool: return String(m.get("tier", "")) == "national")
	assert_true(none.is_empty())
	assert_true(national.size() >= none.size())
	c.gym.repute = { "score": GymRepute.LEVELS[GymRepute.WORLD] }
	assert_true("world" in Stable.signing_tiers(c.gym), "world famous")


func test_better_coaches_wait_for_a_bigger_name() -> void:
	var g: Dictionary = _career().gym
	var two := { "id": "two", "name": "Joe", "role": "striking", "level": 2 }
	var three := { "id": "three", "name": "Jim", "role": "wrestling", "level": 3 }
	assert_eq(Staff.cant_hire(g, { "id": "one", "role": "bjj", "level": 1 }), "", "level 1 comes anywhere")
	assert_string_contains(Staff.cant_hire(g, two), "bigger name")
	g.repute = { "score": GymRepute.LEVELS[GymRepute.TOWN] }
	assert_eq(Staff.cant_hire(g, two), "")
	assert_string_contains(Staff.cant_hire(g, three), "known in the region")
	g.repute = { "score": GymRepute.LEVELS[GymRepute.REGION] }
	assert_eq(Staff.cant_hire(g, three), "")


func test_the_news_says_when_it_moves_a_level_and_not_for_an_old_save() -> void:
	var c: Career = _career()
	c.gym.erase("repute_level")
	c.end_week()
	assert_true(c.gym_news.is_empty(), "the first look sets it quietly")
	for i in 11:  # Past Known in town even after a week's fading.
		_win(c)
	var events: Array = c.run_week()["events"]
	var kinds: Array = events.map(func(e: Dictionary) -> String: return String(e.kind))
	assert_true(Career.GYM_NAME in kinds, str(kinds))
	var moved: Dictionary = events.filter(func(e: Dictionary) -> bool: return String(e.kind) == Career.GYM_NAME)[0]
	assert_true(bool(moved.up))
	assert_eq(int(moved.level), GymRepute.TOWN)
	assert_true(Career.GYM_NAME in Career.JUST_NEWS, "Advance runs on past it")
	assert_eq(Career.event_text(moved), "Your gym is known in town now: more members, and level 2 coaches will come")
	assert_eq(GymRepute.news_text({ "level": 1, "up": false }), "Your gym's name is slipping: known in town now")


func test_a_stable_mans_fight_marks_the_gym() -> void:
	var c: Career = _career(40)
	var w: World = c.world()
	var m: Dictionary = {}
	for p: Dictionary in Stable.prospects(w, c.gym, c.week):
		if bool(p.get("pro", false)):
			m = p
			break
	assert_eq(Stable.offer(w, c.gym, m, c.week, 0.0), "")
	var r := { "kind": "fight", "week": c.week, "a": String(m.id), "b": "nobody", "winner": "a", "method": "ko" }
	Stable.after_fights(w, c.gym, [r])
	var marks: Array = c.gym.get("repute_marks", [])
	assert_eq(marks.size(), 1)
	assert_gt(float(marks[0].points), GymRepute.WIN_PRO, "a pro knockout")
	assert_gt(c.refresh_repute(), 0.0)


func test_it_saves_and_loads() -> void:
	var c: Career = _career()
	for i in 3:
		_win(c)
	GymRepute.mark(c.gym, c.week, -2.0, "left")
	var before: float = c.refresh_repute()
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_almost_eq(back.refresh_repute(), before, 0.01)
