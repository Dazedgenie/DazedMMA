extends GutTest
## Your gym's rooms (sim/world/gym.gd, docs/03 §14.2, D442): rooms at three levels inside the place's floor, what each
## does to training, the sessions that need one, building them with the gym's money and the room shut meanwhile,
## members they bring, tearing one down, and old saves.


func _career(kind: String = "boxing_gym", place: String = "unit", money: int = 5000) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 16
	p.potential = 80
	var gym := { "kind": kind, "culture": "family", "place": place, "name": "Test Gym", "owner_name": "Frank Doyle",
		"owner": "Owns it.", "dues": 40, "members": 16, "members_start": 16, "rent": Gym.rent_for(16, 40) }
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym })
	c.gym_money = money
	c.next_offers_week = 1000  # No fight offers to get in the way.
	return c


## Runs weeks until the gym's building work is done (at most `weeks`).
func _until_built(c: Career, weeks: int = 6) -> Array:
	var events: Array = []
	for i in weeks:
		var report: Dictionary = c.run_week()
		events.append_array(report.events)
		if c.gym.get("building", {}).is_empty():
			break
	return events


func test_every_room_has_a_name_a_size_and_something_it_does() -> void:
	assert_eq(Gym.rooms().size(), 8, "mats, bags, ring, cage, weights, recovery, video, changing rooms")
	for id: String in Gym.rooms():
		var r: Dictionary = Gym.room(id)
		assert_ne(String(r.get("name", "")), "", id)
		assert_between(int(r.get("size", 0)), 1, 2, id)
		assert_false(Gym.effect_lines(id, 1).is_empty(), "%s does something" % id)


func test_a_new_gym_opens_with_its_kinds_rooms_that_fit_its_floor() -> void:
	assert_eq(Gym.starting_rooms("boxing_gym", "unit"), { "bags": 1, "ring": 1 })
	assert_eq(Gym.starting_rooms("bjj_academy", "unit"), { "mats": 1 })
	assert_eq(Gym.starting_rooms("mma_gym", "unit"), { "mats": 1, "bags": 1, "cage": 1 })
	assert_eq(Gym.starting_rooms("mma_gym", "garage"), { "mats": 1, "bags": 1 }, "the cage doesn't fit in a garage")
	assert_eq(Gym.starting_rooms("bjj_academy", "hall"), { "mats": 1, "ring": 1 }, "the old hall comes with its tired ring")
	for g: Dictionary in Gym.offers("Leeds", "england", "boxing_gym_kid", 7):
		assert_false((g.rooms as Dictionary).is_empty(), "every gym on offer has a room")
		assert_lte(Gym.floor_used(g), Gym.floor_size(g), "inside its floor")


func test_a_room_makes_its_kind_of_session_learn_faster_by_its_level() -> void:
	var c: Career = _career("bjj_academy")  # Mats, level 1.
	var with_mats: float = Gym.xp_share(c.gym, "grappling", "rolling")
	c.gym.rooms.erase("mats")
	var bare: float = Gym.xp_share(c.gym, "grappling", "rolling")
	assert_almost_eq(with_mats / bare, 1.08, 0.0001, "+8% a level")
	c.gym.rooms.mats = 3
	assert_almost_eq(Gym.xp_share(c.gym, "grappling", "rolling") / bare, 1.24, 0.0001, "+24% at level 3")
	assert_almost_eq(Gym.xp_share(c.gym, "striking", "heavy_bag"), Gym.xp_share(_career("bjj_academy").gym, "striking", "heavy_bag"), 0.0001,
		"mats do nothing for striking")


func test_three_sessions_need_their_room_and_stand_in_without_it() -> void:
	var lib: TrainingLibrary = TrainingLibrary.shared()
	var c: Career = _career("bjj_academy")  # Mats only.
	assert_false(Gym.can_use(c.gym, lib.session("hard_sparring")), "no ring or cage")
	assert_eq(Gym.stand_in(c.gym, lib.session("hard_sparring")), "light_sparring")
	assert_eq(Gym.stand_in(c.gym, lib.session("shark_tank")), "boxing_drill")
	assert_eq(Gym.stand_in(c.gym, lib.session("film_study")), "meditation")
	assert_eq(Gym.stand_in(c.gym, lib.session("rolling")), "rolling", "everything else works anywhere")
	assert_eq(Gym.needs_text(c.gym, lib.session("hard_sparring")), "Needs the ring or the cage")
	assert_true(Gym.can_use({}, lib.session("film_study")), "a camp with no gym has everything")
	var boxing: Career = _career("boxing_gym")  # Bags and a ring.
	assert_true(Gym.can_use(boxing.gym, lib.session("hard_sparring")))
	assert_false(Gym.can_use(boxing.gym, lib.session("shark_tank")))


func test_a_week_planned_with_a_session_the_gym_cant_do_does_its_stand_in() -> void:
	var c: Career = _career("bjj_academy")
	var plan: Dictionary = TrainingLibrary.shared().plan(Career.BETWEEN_PLAN).duplicate(true)
	for day: Array in plan.days:
		day[0] = "hard_sparring"
	var report: Dictionary = c.run_week(plan)
	var done: Array = (report.slots as Array).map(func(s: Dictionary) -> String: return String(s.session))
	assert_false("hard_sparring" in done, "no ring: no hard sparring")
	assert_true("light_sparring" in done, "light sparring in its place")


func test_building_a_room_costs_the_gyms_money_and_shuts_it_until_its_done() -> void:
	var c: Career = _career("boxing_gym", "unit", 1500)
	var before: int = c.gym_money
	assert_eq(c.build_room("ring"), "", "the ring goes to level 2")
	assert_eq(c.gym_money, before - Gym.ROOM_COSTS[1], "$1,000 for level 2")
	assert_eq(Gym.working_level(c.gym, "ring"), 0, "shut while it's done")
	assert_false(Gym.can_use(c.gym, TrainingLibrary.shared().session("hard_sparring")), "no hard sparring meanwhile")
	assert_ne(c.build_room("bags"), "", "one job at a time")
	var weeks: int = Gym.build_weeks("ring", 2)
	assert_between(weeks, 1, Gym.BUILD_WEEKS_MAX)
	var events: Array = _until_built(c)
	assert_eq(Gym.level(c.gym, "ring"), 2)
	assert_eq(Gym.working_level(c.gym, "ring"), 2, "open again")
	var news: Array = events.filter(func(e: Dictionary) -> bool: return String(e.kind) == Career.ROOM_DONE)
	assert_eq(news.size(), 1, "it's news when it's done")
	assert_eq(Career.event_text(news[0]), "The ring is level 2 now")


func test_a_room_takes_one_to_four_weeks_by_its_level_and_size() -> void:
	assert_eq(Gym.build_weeks("bags", 1), 1)
	assert_eq(Gym.build_weeks("mats", 1), 2, "a big room takes a week longer")
	assert_eq(Gym.build_weeks("cage", 3), 4)
	assert_eq(Gym.build_weeks("video", 3), 3)


func test_a_room_needs_floor_and_money_and_stops_at_level_three() -> void:
	var c: Career = _career("mma_gym", "garage", 200)  # Mats and bags: 3 of 4 squares.
	assert_eq(Gym.floor_size(c.gym), 4)
	assert_eq(Gym.floor_used(c.gym), 3)
	assert_string_contains(Gym.cant_build(c.gym, "cage", 99999), "Not enough floor")
	assert_string_contains(Gym.cant_build(c.gym, "video", c.gym_money), "costs $300")
	c.gym.rooms.bags = Gym.ROOM_LEVELS
	assert_eq(Gym.cant_build(c.gym, "bags", 99999), "At the top level")
	assert_eq(Gym.build_cost(c.gym, "bags"), 0)


func test_each_level_you_build_brings_a_member_in() -> void:
	var c: Career = _career("boxing_gym", "unit", 5000)
	var target: int = Gym.members_target(c.gym, 0)
	assert_eq(target, 16, "the rooms it opened with don't count")
	c.build_room("video")
	_until_built(c)
	assert_eq(Gym.members_target(c.gym, 0), 17)
	c.build_room("ring")
	_until_built(c)
	assert_eq(Gym.members_target(c.gym, 0), 18)


func test_changing_rooms_hold_more_members() -> void:
	var c: Career = _career("boxing_gym", "unit")
	var cap: int = Gym.cap(c.gym)
	c.gym.rooms.changing = 2
	assert_eq(Gym.cap(c.gym), cap + 10)


func test_tearing_a_room_down_frees_its_floor_and_gives_a_quarter_back() -> void:
	var c: Career = _career("boxing_gym", "unit", 5000)
	c.build_room("weights")
	_until_built(c)
	var used: int = Gym.floor_used(c.gym)
	var money: int = c.gym_money
	assert_eq(c.tear_down_room("weights"), "")
	assert_eq(c.gym_money, money + roundi(Gym.ROOM_COSTS[0] * Gym.TEAR_DOWN_BACK), "a quarter of the $300 back")
	var events: Array = _until_built(c)
	assert_eq(Gym.level(c.gym, "weights"), 0)
	assert_eq(Gym.floor_used(c.gym), used - 1)
	assert_true(events.any(func(e: Dictionary) -> bool: return String(e.kind) == Career.ROOM_DONE and int(e.level) == 0))


func test_the_recovery_room_clears_fatigue_overnight_and_heals_faster() -> void:
	var c: Career = _career("boxing_gym")
	assert_eq(Gym.night_share(c.gym), 1.0)
	c.gym.rooms.recovery = 2
	assert_almost_eq(Gym.night_share(c.gym), 0.9, 0.0001)
	assert_eq(Gym.extra_healing(c.gym), 2)
	var plain: TrainingCamp = _career("boxing_gym").trainee
	var plan: Dictionary = TrainingLibrary.shared().plan("all_out")
	var tired: float = plain.forecast(plan).fatigue_end
	var rested: float = c.trainee.forecast(plan).fatigue_end
	assert_lt(rested, tired, "less fatigue at the end of the week")


func test_the_video_room_finds_habits_more_often() -> void:
	var c: Career = _career("boxing_gym")
	var before: float = Scouting.find_chance(c, "nobody")
	c.gym.rooms.video = 2
	assert_almost_eq(Scouting.find_chance(c, "nobody") - before, 0.1, 0.0001)


func test_a_ring_makes_sparring_safer() -> void:
	var c: Career = _career("boxing_gym")  # A ring at level 1.
	var safer: float = Gym.injury_share(c.gym, "sparring")
	c.gym.rooms.erase("ring")
	assert_almost_eq(Gym.injury_share(c.gym, "sparring") - safer, 0.1, 0.0001)


func test_the_rooms_and_building_save_with_the_career() -> void:
	var c: Career = _career("boxing_gym", "unit", 5000)
	c.build_room("ring")
	var back: Career = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.gym.rooms, c.gym.rooms)
	assert_eq(back.gym.building, c.gym.building)
	assert_eq(back.gym.spent, c.gym.spent)
	assert_typeof(back.gym.building.done, TYPE_INT)


func test_a_save_from_before_rooms_opens_with_its_kinds_rooms() -> void:
	var c: Career = _career("muay_thai_camp")
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	for key: String in ["rooms", "spent", "building", "levels_start"]:
		d.gym.erase(key)
	var back: Career = Career.from_dict(d)
	assert_eq(back.gym.rooms, { "bags": 1, "ring": 1 })
	assert_eq(Gym.members_target(back.gym, 0), 16, "no members from rooms it already had")


func test_a_maxed_gym_speeds_learning_by_a_set_amount_not_runaway() -> void:
	var c: Career = _career("mma_gym", "hall")
	for id: String in Gym.rooms():
		c.gym.rooms[id] = Gym.ROOM_LEVELS
	for kind: String in ["striking", "wrestling", "grappling", "sparring", "conditioning", "mind"]:
		assert_lte(Gym.room_share(c.gym, kind, ""), 1.25, "%s at most +25%% from rooms" % kind)
	assert_lte(Gym.room_share(c.gym, "wrestling", "clinch_work"), 1.6)
