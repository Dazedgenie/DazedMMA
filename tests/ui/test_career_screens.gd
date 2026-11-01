extends GutTest
## The title screen, new career, load career and the career hub (ui/title_screen.gd, ui/new_career_screen.gd,
## ui/load_screen.gd, ui/career_hub.gd; docs/03 §10.2, D302).

const TEST_DIR := "user://test_career_screens/"


func before_each() -> void:
	_clear()


func after_all() -> void:
	_clear()


func _clear() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		for file in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(TEST_DIR.path_join(file))


func _career(fighter_name: String = "Danny Hill") -> Career:
	return Career.start({ "coach": "Sam Reed", "name": fighter_name, "nickname": "The Kid", "hometown": "Leeds", "country": "England",
		"background": "wrestling_family", "stance": "orthodox" }, 3, FighterLibrary.load_dir())


func test_the_title_has_the_name_the_studio_and_the_menu() -> void:
	var title: TitleScreen = add_child_autofree(TitleScreen.new())
	title.save_dir = TEST_DIR
	title.refresh()
	var labels: Array[String] = title.button_labels()
	assert_eq(str(labels.slice(0, 4)), str(["Continue", "New career", "Load career", "Quick fight"]))
	assert_false(title.can_continue(), "nothing to continue yet")
	assert_string_contains(title.text(), "No career saved yet")


func test_continue_names_the_career_saved_last() -> void:
	CareerSaves.save(_career("Danny Hill"), 1, TEST_DIR)
	var title: TitleScreen = add_child_autofree(TitleScreen.new())
	title.save_dir = TEST_DIR
	title.refresh()
	assert_true(title.can_continue())
	assert_string_contains(title.text(), "Danny Hill 'The Kid' · age 16 · Mon 4 Jan 2027")
	watch_signals(title)
	title.press("Continue")
	assert_signal_emitted_with_parameters(title, "continue_pressed", [1])


func test_a_new_career_opens_rolled_and_ready_to_start() -> void:
	var screen: NewCareerScreen = add_child_autofree(NewCareerScreen.new())
	screen.roll(4)
	var picked: Dictionary = screen.choices()
	for key: String in ["coach", "coach_background", "coach_specialty", "name", "nickname", "hometown", "country", "background", "stance"]:
		assert_ne(String(picked[key]), "", key)
	assert_eq(screen.problem(), "")
	watch_signals(screen)
	screen.press_start()
	assert_signal_emitted(screen, "start_pressed")
	screen.roll(4)
	assert_eq(screen.choices(), picked, "the same roll fills the same")


func test_a_new_career_needs_both_names_and_a_free_slot() -> void:
	var screen: NewCareerScreen = add_child_autofree(NewCareerScreen.new())
	screen.roll(1)
	screen.set_field("name", "  ")
	assert_string_contains(screen.problem(), "fighter a name")
	watch_signals(screen)
	screen.press_start()
	assert_signal_not_emitted(screen, "start_pressed")
	screen.set_field("name", "Danny Hill")
	screen.set_field("coach", "")
	assert_string_contains(screen.problem(), "you're his coach")
	screen.set_field("coach", "Sam")
	screen.slot_free = false
	assert_string_contains(screen.problem(), "delete one")


func test_picking_a_background_shows_what_it_gives_him() -> void:
	var screen: NewCareerScreen = add_child_autofree(NewCareerScreen.new())
	screen.set_play_childhood(false)
	screen.pick_background("boxing_gym_kid")
	assert_eq(screen.background_id(), "boxing_gym_kid")
	assert_string_contains(screen.text(), "Boxing gym kid")
	assert_string_contains(screen.text(), "Strong: Boxing")
	assert_string_contains(screen.text(), "old boxing coach")


func test_picking_your_specialty_says_what_it_does_and_the_hub_shows_it() -> void:
	var screen: NewCareerScreen = add_child_autofree(NewCareerScreen.new())
	screen.roll(2)
	screen.pick_coach("pe_teacher", Coach.TACTICIAN)
	assert_eq(screen.choices().coach_background, "pe_teacher")
	assert_eq(screen.choices().coach_specialty, Coach.TACTICIAN)
	assert_string_contains(screen.text(), "taught PE at his school")
	assert_string_contains(screen.text(), Coach.specialty_does(Coach.TACTICIAN))
	var choices: Dictionary = screen.choices()
	var c: Career = Career.start(choices, 3, FighterLibrary.load_dir())
	var hub: CareerHub = add_child_autofree(CareerHub.new())
	hub.show_career(c)
	assert_string_contains(hub.text(), "coached by %s (Tactician)" % choices.coach)
	assert_string_contains(hub.text(), "Your specialty: Tactician.")


func test_the_load_screen_shows_each_slot_and_deletes_only_on_the_second_press() -> void:
	CareerSaves.save(_career("Danny Hill"), 0, TEST_DIR)
	var screen: LoadScreen = add_child_autofree(LoadScreen.new())
	screen.save_dir = TEST_DIR
	screen.refresh()
	assert_string_contains(screen.text(), "Danny Hill")
	assert_string_contains(screen.text(), "Amateur 0-0-0")
	assert_string_contains(screen.text(), "Empty")
	screen.press_delete(0)
	assert_false(CareerSaves.info(0, TEST_DIR).is_empty(), "the first press only asks")
	screen.press_delete(0)
	assert_true(CareerSaves.info(0, TEST_DIR).is_empty(), "the second press deletes")
	assert_eq(LoadScreen.saved_text("2026-10-31T19:04:22"), "31 Oct 2026, 19:04 UTC")


func test_the_hub_shows_who_he_is_and_every_stat() -> void:
	var c: Career = _career()
	var hub: CareerHub = add_child_autofree(CareerHub.new())
	hub.show_career(c)
	assert_string_contains(hub.text(), "DANNY HILL 'THE KID'")
	assert_string_contains(hub.text(), "Age 16")
	assert_string_contains(hub.text(), "Mon 4 Jan 2027")
	assert_string_contains(hub.text(), "Wrestling family")
	assert_string_contains(hub.text(), "From Leeds, England")
	assert_string_contains(hub.text(), "(scouted)")
	var rows: Array[Dictionary] = CareerHub.stat_rows(c.trainee, JSON.parse_string(FileAccess.get_file_as_string("res://data/enums/stats.json")).values)
	assert_eq(rows.size(), TrainingCamp.STAT_NAMES.size() + CampPlanner.GROUPS.size(), "every stat under its group")
	var report: Dictionary = c.run_week()
	hub.show_career(c, [report])
	assert_string_contains(hub.text(), "Mon 11 Jan 2027")
	assert_string_contains(hub.text(), "Last week:")


func test_the_hub_shows_what_is_next_his_fights_and_the_calendar() -> void:
	var c: Career = _career()
	var hub: CareerHub = add_child_autofree(CareerHub.new())
	hub.show_career(c)
	assert_string_contains(hub.text(), "Free to fight")
	assert_string_contains(hub.text(), "No fights yet")
	assert_string_contains(hub.text(), "This week")
	assert_string_contains(hub.text(), "Feels: fresh")
	c.add_opponent({ "id": "opp_1", "name": "First Man" })
	c.add_fight({ "result": "win", "opponent": "opp_1", "method": "KO", "round": 1 })
	c.trainee.injured_days = 10
	c.trainee.injury_area = "legs"
	hub.show_career(c)
	assert_string_contains(hub.text(), "W vs First Man · KO, R1")
	assert_string_contains(hub.text(), "Sat 9 Jan 2027 · amateur")
	assert_string_contains(hub.text(), "Hurt (legs): 10 days to heal")
	assert_string_contains(hub.text(), "Healed", "the calendar says when")


func test_picking_a_week_plan_on_the_hub_changes_his_weeks() -> void:
	var c: Career = _career()
	var hub: CareerHub = add_child_autofree(CareerHub.new())
	hub.show_career(c)
	hub.pick_plan("time_off")
	assert_eq(c.week_plan, "time_off")
	assert_string_contains(hub.text(), "time off")



func test_offers_show_on_the_hub_as_cards_to_take_or_turn_down() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	var hub: CareerHub = add_child_autofree(CareerHub.new())
	hub.show_career(c)
	assert_eq(hub.offer_ids().size(), c.offers.size())
	var o: Dictionary = c.offers[0]
	assert_string_contains(hub.text(), String(o.profile.name))
	assert_string_contains(hub.text(), "fight offer")
	assert_string_contains(hub.text(), "Scouted: Striking")
	assert_string_contains(hub.text(), "Teen amateur")
	assert_string_contains(hub.text(), "Amateur: no purse")
	assert_string_contains(CareerHub.purse_text({ "show": 1000, "win": 1000 }), "$1000 to show")
	watch_signals(hub)
	hub.press_accept(String(o.id))
	assert_signal_emitted_with_parameters(hub, "accept_pressed", [String(o.id)])
	hub.press_decline(String(o.id))
	assert_signal_emitted_with_parameters(hub, "decline_pressed", [String(o.id)])


func test_once_booked_the_hub_sends_him_to_camp() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	c.accept(String(c.offers[0].id))
	var hub: CareerHub = add_child_autofree(CareerHub.new())
	hub.show_career(c)
	assert_true(hub.offer_ids().is_empty())
	assert_string_contains(hub.text(), "Booked:")
	assert_string_contains(hub.text(), "Go to camp: %d weeks to fight night" % c.camp_weeks_left())
	watch_signals(hub)
	hub.press_camp()
	assert_signal_emitted(hub, "camp_pressed")
	assert_false(hub.can_turn_pro())


func test_his_childhood_is_three_scenes_and_then_who_he_became() -> void:
	var screen: ChildhoodScreen = add_child_autofree(ChildhoodScreen.new())
	screen.begin(9, { "name": "Danny Hill", "country_id": "england" })
	assert_eq(screen.scene_ids().size(), 3)
	assert_string_contains(screen.text(), "AGE 8 · 1 OF 3")
	screen.press_next()
	assert_string_contains(screen.text(), "AGE 8", "Next waits for a choice")
	for i in 3:
		screen.press_choice(i)
		assert_eq(screen.picks.size(), i + 1)
		screen.press_choice(0)
		assert_eq(screen.picks.size(), i + 1, "one choice a scene")
		screen.press_next()
	assert_true(screen.on_summary())
	assert_string_contains(screen.text(), "WHO HE BECAME")
	assert_string_contains(screen.text(), "He starts with $")
	watch_signals(screen)
	screen.press_start()
	assert_signal_emitted_with_parameters(screen, "finished", [screen.picks])


func test_play_his_childhood_is_on_by_default_and_greys_out_the_list() -> void:
	var screen: NewCareerScreen = add_child_autofree(NewCareerScreen.new())
	screen.roll(4)
	assert_true(screen.play_childhood())
	assert_true(screen.choices().play_childhood)
	assert_ne(screen.choices().country_id, "")
	assert_string_contains(screen.text(), "His childhood decides")
	screen.set_play_childhood(false)
	assert_false(screen.choices().play_childhood)
	assert_string_contains(screen.text(), "Strong:")


func test_where_you_coach_offers_three_gyms_then_the_walk_in() -> void:
	var screen: GymScreen = add_child_autofree(GymScreen.new())
	screen.begin({ "coach": "Sam Reed", "name": "Danny Hill", "hometown": "Leeds", "country_id": "england", "background": "farm_kid" }, 5)
	assert_eq(screen.gyms.size(), 3)
	assert_string_contains(screen.text(), "WHERE YOU COACH")
	assert_string_contains(screen.text(), "a month")
	watch_signals(screen)
	screen.press_start()
	assert_signal_not_emitted(screen, "finished", "pick a gym first")
	screen.pick(2)
	assert_true(screen.on_walk_in())
	assert_string_contains(screen.text(), "THE WALK-IN")
	assert_string_contains(screen.text(), String(screen.gyms[2].name))
	screen.press_back()
	assert_false(screen.on_walk_in(), "back to the three gyms")
	screen.pick(2)
	screen.press_start()
	assert_signal_emitted_with_parameters(screen, "finished", [screen.gyms[2]])


func test_a_career_camp_shows_his_school_mornings_and_the_card() -> void:
	var c: Career = _career()
	c.run_week("time_off")
	assert_true(c.accept(String(c.offers[0].id)))
	var planner: CampPlanner = add_child_autofree(CampPlanner.new(c.profile(), 1))
	planner.use_career(c)
	for i: int in School.MORNINGS:
		assert_string_contains(planner.tile_text(i), "School", "slot %d is at school (D314)" % i)
		assert_true(planner._slots[i].disabled, "and can't be changed")
	for i: int in School.EVENINGS:
		assert_string_contains(planner.tile_text(i), "Homework", "slot %d is homework" % i)
		assert_true(planner._slots[i].disabled, "and can't be changed")
	assert_false(planner.tile_text(1).contains("School"), "Monday evening is his")
	assert_false(planner._slots[1].disabled)
	assert_string_contains(planner._days_note.text, String(c.booked.card.name))
