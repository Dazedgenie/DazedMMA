extends GutTest
## Your gym's page and its floor plan (ui/gym_page.gd, ui/floor_plan.gd, docs/03 §14.2, D442), the hub's Your gym tab,
## and the camp planner at a gym without a room.


func _career(kind: String = "boxing_gym", place: String = "unit", money: int = 2000) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 16
	p.potential = 80
	var gym := { "kind": kind, "culture": "family", "place": place, "name": "Hill's Gym", "owner_name": "Frank Doyle",
		"owner": "Owns it.", "dues": 40, "members": 16, "members_start": 16, "rent": Gym.rent_for(16, 40) }
	var c: Career = Career.create(p, 3, { "coach": "Sam", "gym": gym })
	c.gym_money = money
	c.next_offers_week = 1000
	return c


func test_the_floor_plan_lays_every_room_on_its_own_squares_inside_the_floor() -> void:
	for place: String in Gym.places():
		var g: Dictionary = { "place": place, "rooms": {} }
		var free: int = Gym.floor_size(g)
		for id: String in Gym.rooms():
			if int(Gym.room(id).size) <= free:
				g.rooms[id] = 1
				free -= int(Gym.room(id).size)
		var cells: Dictionary = FloorPlan.cells_for(g)
		var seen: Dictionary = {}
		var grid: Vector2i = FloorPlan.grid_of(Gym.floor_size(g))
		for id: String in cells:
			assert_eq((cells[id] as Array).size(), int(Gym.room(id).size), "%s takes its size" % id)
			for cell: Vector2i in cells[id]:
				assert_false(seen.has(cell), "%s: one room a square" % place)
				seen[cell] = true
				assert_lt(cell.x, grid.x)
				assert_lt(cell.y * grid.x + cell.x, Gym.floor_size(g), "inside the floor")
		var two: Array = (cells.values().filter(func(c: Array) -> bool: return c.size() == 2))
		for c: Array in two:
			assert_eq(absi((c[0] as Vector2i).x - (c[1] as Vector2i).x) + absi((c[0] as Vector2i).y - (c[1] as Vector2i).y), 1, "a big room's squares touch")


func test_the_gym_page_shows_the_place_its_money_and_what_you_can_build() -> void:
	var c: Career = _career()
	var page: GymPage = add_child_autofree(GymPage.new())
	page.show_gym(c)
	assert_true(page.visible)
	assert_string_contains(page._title.text, "HILL'S GYM")
	assert_string_contains(page._subtitle.text, "3 of 6 squares")
	assert_string_contains(GymPage.money_text(c), "$2000")
	assert_false(page.list_buttons.has("ring"), "the ring's already built")
	assert_true(page.list_buttons.has("video"))
	assert_false((page.list_buttons.video as Button).disabled)
	assert_string_contains(GymPage.room_text(c, "ring"), "Level 1 of 3 now")
	assert_string_contains(GymPage.room_text(c, "ring"), "hard sparring")


func test_building_from_the_page_spends_the_gyms_money_and_draws_the_room_shut() -> void:
	var c: Career = _career()
	var page: GymPage = add_child_autofree(GymPage.new())
	page.show_gym(c)
	watch_signals(page)
	assert_eq(page.build("video"), "")
	assert_signal_emitted(page, "changed")
	assert_eq(c.gym_money, 2000 - Gym.ROOM_COSTS[0])
	assert_string_contains(GymPage.money_text(c), "building the video room: 1 week")
	assert_ne(page.build("mats"), "", "one job at a time")
	assert_string_contains(CareerHub.gym_text(c), "Building the video room")
	assert_eq(c.calendar()[0].events.filter(func(e: Dictionary) -> bool: return String(e.kind) == Career.ROOM_DONE).size(), 1, "on the calendar")


func test_the_hub_has_a_your_gym_tab() -> void:
	var c: Career = _career()
	var hub: CareerHub = add_child_autofree(CareerHub.new())
	hub.show_career(c)
	assert_true(hub.gym_tab.visible)
	watch_signals(hub)
	hub.gym_tab.pressed.emit()
	assert_signal_emitted(hub, "gym_pressed")


func test_the_camp_planner_offers_a_sessions_stand_in_when_the_gym_hasnt_its_room() -> void:
	var c: Career = _career("bjj_academy")
	c.run_week("time_off")
	c.next_offers_week = 0
	c.run_week("time_off")
	if c.offers.is_empty():
		pass_test("no offer this week")
		return
	assert_true(c.accept(String(c.offers[0].id)))
	var planner: CampPlanner = add_child_autofree(CampPlanner.new(c.profile(), 1))
	planner.use_career(c)
	planner.set_slot(11, "hard_sparring")
	assert_eq(String(planner.week_plan().days[5][1]), "light_sparring", "no ring or cage: light sparring")
	planner.set_slot(11, "rolling")
	assert_eq(String(planner.week_plan().days[5][1]), "rolling")
