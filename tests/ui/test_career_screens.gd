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
	for key: String in ["coach", "name", "nickname", "hometown", "country", "background", "stance"]:
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
	screen.pick_background("boxing_gym_kid")
	assert_eq(screen.background_id(), "boxing_gym_kid")
	assert_string_contains(screen.text(), "Boxing gym kid")
	assert_string_contains(screen.text(), "Strong: Boxing")
	assert_string_contains(screen.text(), "old boxing coach")


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
	hub.show_career(c, report)
	assert_string_contains(hub.text(), "Mon 11 Jan 2027")
	assert_string_contains(hub.text(), "Last week:")
