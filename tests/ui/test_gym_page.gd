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


func test_the_coaches_tab_lists_who_is_looking_and_hiring_puts_him_on_your_staff() -> void:
	var c: Career = _career()
	c.gym.looking = [{ "id": "a", "name": "Joe Hart", "role": "striking", "level": 2, "personality": "hard", "country_id": "england",
		"age": 41, "line": "Retired regional pro, 14-6-0", "from": "" },
		{ "id": "b", "name": "Ann Lee", "role": "nutrition", "level": 1, "personality": "patient", "country_id": "england",
		"age": 35, "line": "A sports dietitian", "from": "" }]
	c.gym.looking_at = Staff.month_key(c.date())
	var page: GymPage = add_child_autofree(GymPage.new())
	page.show_gym(c)
	assert_false(page.coaches.visible, "rooms first")
	page.coaches_tab.pressed.emit()
	assert_true(page.coaches.visible)
	assert_eq(page.coaches.hire_buttons.size(), 2)
	assert_string_contains(page.coaches.hire_buttons[0].text, "$40 a week")
	watch_signals(page)
	assert_eq(page.coaches.hire(0), "")
	assert_signal_emitted(page, "changed")
	assert_true(page.coaches.let_go_buttons.has("striking"))
	assert_eq(page.coaches.hire_buttons.size(), 1, "off the list")
	assert_string_contains(GymPage.money_text(c), "wages $40 a week")
	assert_string_contains(CareerHub.gym_text(c), "Joe Hart (striking)")
	assert_string_contains(CoachesView.coach_text(Staff.coaches(c.gym)[0], true), "Striking stats learn 15% faster")
	assert_eq(page.coaches.let_go("striking"), "")
	assert_false(page.coaches.let_go_buttons.has("striking"))


func test_the_fighters_tab_shows_him_and_the_gyms_lads_and_what_the_best_partner_does() -> void:
	var c: Career = _career()
	c.gym.lads = [{ "id": "nobody_a", "name": "Jake Moss", "style": "boxer", "born": 17.0, "avg": 90.0, "record": "4-1-0",
		"pro": false, "country": "England", "since": 0 }]
	c.gym.former = []
	var page: GymPage = add_child_autofree(GymPage.new())
	page.show_gym(c)
	page.fighters_tab.pressed.emit()
	assert_true(page.fighters.visible)
	assert_false(page.coaches.visible)
	page.show_tab(GymPage.FIGHTERS)
	assert_false(page.rooms_tab.button_pressed, "only the Fighters tab lit")
	assert_eq(page.fighters.lad_rows.size(), 1)
	assert_string_contains(LadsView.lad_text(c.gym.lads[0], 40.0, c.week), "Well ahead of him")
	assert_string_contains(LadsView.lad_text(c.gym.lads[0], 40.0, c.week), "4-1-0 amateur")
	assert_string_contains(LadsView.side_text(c), "Jake Moss")
	assert_string_contains(LadsView.side_text(c), "15% faster")
	assert_string_contains(CareerHub.gym_text(c), "1 other lad trains here")
	c.gym.lads = []
	assert_string_contains(LadsView.side_text(c), "Nobody to spar with")


func test_the_stable_tab_lists_who_you_could_sign_and_signing_puts_him_in_your_stable() -> void:
	var c: Career = _career()
	c.gym.members = 30
	var page: GymPage = add_child_autofree(GymPage.new())
	page.show_gym(c)
	page.stable_tab.pressed.emit()
	assert_true(page.stable.visible)
	assert_false(page.fighters.visible)
	assert_false(page.rooms_tab.button_pressed, "only the Stable tab lit")
	assert_gt(page.stable.sign_buttons.size(), 0)
	assert_string_contains(StableView.prospect_text(c.world(), c.gym, page.stable.shown_prospects[0], c.week), "he says yes")
	var m: Dictionary = page.stable.shown_prospects[0]
	assert_eq(Stable.offer(c.world(), c.gym, m, c.week, 0.0), "")
	watch_signals(page)
	page.stable.refresh()
	assert_true(page.stable.focus_pickers.has(String(m.id)))
	assert_true(page.stable.set_focus(String(m.id), "wrestling"))
	assert_signal_emitted(page, "changed")
	assert_string_contains(StableView.fighter_text(c.gym, Stable.entry(c.gym, String(m.id)), c.week), "Wrestling: he learns")
	assert_string_contains(CareerHub.gym_text(c), "Your stable: %s · 2 of 3 places" % String(m.name))
	assert_string_contains(LadsView.side_text(c), "Best partner")
	assert_eq(page.stable.let_go(String(m.id)), "")
	assert_false(page.stable.focus_pickers.has(String(m.id)))
	var why: String = page.stable.offer_place(0)
	assert_true(why == "" or "said no" in why or "ask again" in why, why)


func test_the_stable_tab_shows_a_mans_next_fight_and_can_turn_it_down() -> void:
	var c: Career = _career()
	c.gym.members = 30
	var m: Dictionary = c.stable_prospects()[0]
	assert_eq(Stable.offer(c.world(), c.gym, m, c.week, 0.0), "")
	var e: Dictionary = Stable.entry(c.gym, String(m.id))
	e.booked = { "opponent": "x", "opponent_name": "Tom Reid", "week": c.week + 3, "card": "NCC 14", "promotion": "", "ruleset": "pro" }
	var page: GymPage = add_child_autofree(GymPage.new())
	page.show_gym(c)
	page.show_tab(GymPage.STABLE)
	assert_true(page.stable.turn_down_buttons.has(String(m.id)))
	assert_string_contains(StableView.fighter_text(c.gym, e, c.week, "Next: Tom Reid, Sat · NCC 14"), "Next: Tom Reid")
	assert_true(page.stable.turn_down(String(m.id)))
	assert_false(page.stable.turn_down_buttons.has(String(m.id)))
	assert_true(Stable.booking(Stable.entry(c.gym, String(m.id))).is_empty())
