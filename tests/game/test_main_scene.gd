extends GutTest
## The fight screen (game/main.tscn, #19): a full 3-round fight is playable with the
## keyboard and the mouse, from the setup to the result.

const FRAME: float = 0.05
const TEST_DIR := "user://test_main_scene_fights/"
const SAVE_DIR := "user://test_main_scene_saves/"

var _main: Node


func before_each() -> void:
	_main = load("res://game/main.tscn").instantiate()
	add_child_autofree(_main)
	_main.record_dir = TEST_DIR
	_main.save_dir = SAVE_DIR


func after_each() -> void:
	for dir: String in [TEST_DIR, SAVE_DIR]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	_main._unhandled_input(event)


func _start(seed_value: int = 11) -> void:
	var s: Dictionary = _main.setup.settings()
	s.seed = seed_value
	s.rules = [[1, "catch_kick_and_shoot", 80.0], [2, "", 80.0]]
	_main.start_fight(s)


func test_the_game_opens_on_the_title_and_quick_fight_opens_the_fight_setup() -> void:
	assert_true(_main.title.visible)
	assert_false(_main.setup.visible)
	assert_eq(_main.state, _main.TITLE)
	_main.title.press("Quick fight")
	assert_false(_main.title.visible)
	assert_true(_main.setup.visible)
	assert_false(_main.hud.visible)
	assert_eq(_main.setup.settings().red, "wrestler", "the playtest matchup comes first")


func test_hotkeys_make_calls_and_change_the_speed() -> void:
	_start()
	_press(KEY_4)
	_press(KEY_7)
	_press(KEY_Q)
	_press(KEY_E)
	_main._process(FRAME)
	var calls: Array = _main.driver.sim.events.filter(func(e: FightEvent) -> bool: return e.type == FightEvent.CALL_HEARD and e.actor == 0)
	assert_eq(calls.map(func(e: FightEvent) -> String: return e.data.call_id), ["takedown", "feint", "catch_the_kick", "fire_back"], "7 is Feint! standing, Get up! on the ground; E is Fire back! (D133)")
	_press(KEY_SPACE)
	assert_eq(_main.driver.speed, FightDriver.SLOW)
	_press(KEY_F)
	assert_eq(_main.driver.speed, FightDriver.FAST)
	_press(KEY_P)
	assert_false(_main.driver.paused, "pause is for Easy only (D50)")


func test_easy_lets_the_player_pause() -> void:
	var s: Dictionary = _main.setup.settings()
	s.easy = true
	_main.start_fight(s)
	_press(KEY_P)
	assert_true(_main.driver.paused)


func test_a_full_three_round_fight_plays_through_the_bell_to_the_result() -> void:
	_start()
	_main.driver.speed = FightDriver.FAST
	var breaks: int = 0
	var frames: int = 0
	while _main.state != _main.OVER and frames < 20000:
		frames += 1
		_main._process(FRAME)
		if frames % 200 == 0 and _main.state == _main.FIGHT:
			_press(KEY_4)
		if _main.state == _main.ROUND_BREAK:
			breaks += 1
			assert_string_contains(_main.hud.dialog_title(), "End of round")
			_main._start_next_round()
	var sim: FightSim = _main.driver.sim
	assert_true(sim.is_over())
	assert_true(_main.result.visible, "the result screen (D173)")
	assert_string_contains(_main.result.text(), "CUT OFF THE CAGE", "how long each fighter circled and cut off (D119)")
	assert_true(FileAccess.file_exists(_main.last_record_path), "the fight is saved for the playtest notes")
	if sim.events[-1].data.result in [FightSim.RESULT_KO, FightSim.RESULT_TKO, FightSim.RESULT_SUB]:
		pass_test("finished inside the distance after %d breaks" % breaks)
	else:
		assert_eq(breaks, 2, "two corners between three rounds")
		assert_eq(sim.clock.current_round, 3)


func test_the_menu_holds_the_fight_and_the_towel_ends_it() -> void:
	_start()
	_main._process(FRAME)
	_press(KEY_ESCAPE)
	assert_eq(_main.hud.dialog_title(), "Paused")
	var at: int = _main.driver.sim.now
	_main._process(1.0)
	assert_eq(_main.driver.sim.now, at, "the menu holds the fight")
	_press(KEY_ESCAPE)
	assert_false(_main.hud.dialog_open())
	_press(KEY_T)
	assert_eq(_main.hud.dialog_title(), "Throw in the towel?")
	_main.driver.throw_towel()
	assert_true(_main.result.visible)
	assert_string_contains(_main.result.text(), "threw in the towel")
	assert_eq(_main.state, _main.OVER)


func test_a_playtest_fight_opens_on_its_tip_with_only_its_calls() -> void:
	_main.setup.pick_step("fight_1_first_calls")
	_main.start_fight(_main.setup.settings())
	assert_eq(_main.hud.dialog_title(), "Playtest 1: your first calls")
	var at: int = _main.driver.sim.now
	_main._process(1.0)
	assert_eq(_main.driver.sim.now, at, "the tip holds the fight")
	_main._start_after_tip()
	assert_null(_main.hud.call_button("survive"), "only the step's calls are on the bar")
	assert_not_null(_main.hud.call_button("takedown"))
	_press(KEY_8)
	_main._process(FRAME)
	assert_eq(_main.driver.sim.events.filter(func(e: FightEvent) -> bool: return e.type == FightEvent.CALL_HEARD and e.actor == 0).size(), 0)


func test_after_a_playtest_fight_the_next_one_is_offered() -> void:
	_main.setup.pick_step("fight_1_first_calls")
	_main.start_fight(_main.setup.settings())
	_main._start_after_tip()
	_main.driver.throw_towel()
	assert_eq(_main.result.button_labels()[0], "Next: Playtest 2: catch the kick")
	_main.result.press(0)
	assert_false(_main.result.visible, "the next fight hides the result")
	assert_eq(_main.settings.step, "fight_2_catch_the_kick")
	assert_eq(_main.settings.blue, "kicker")


func test_a_camp_before_the_fight_sends_the_trained_fighter_in_and_the_fight_still_replays() -> void:
	_main.open_camp(_main.setup.settings())
	assert_false(_main.setup.visible)
	assert_not_null(_main.planner)
	_main.planner.run_rest()
	_main.planner._fight.pressed.emit()
	assert_null(_main.planner, "the planner closes for the fight")
	assert_eq(_main.driver.sim.fighters[0].id, "wrestler_camp")
	assert_string_contains(_main.settings.label, "after camp")
	var sim: FightSim = _main.driver.sim
	sim.run_to_end()
	var record: Dictionary = JSON.parse_string(JSON.stringify(FightRecord.build(sim, _main.settings)))
	assert_true(record.profiles.has("wrestler_camp"), "the trained fighter is kept with the fight")
	assert_eq(record.settings.camp.weeks.size(), CampPlanner.WEEKS_DEFAULT)
	assert_true(PlaytestReport.replays(record), "a fight after camp replays from its record")


func test_back_from_the_camp_goes_to_the_setup() -> void:
	_main.open_camp(_main.setup.settings())
	_main.planner.back_pressed.emit()
	assert_null(_main.planner)
	assert_true(_main.setup.visible)


func test_after_a_fight_taken_hurt_the_result_says_how_the_injury_held_up() -> void:
	_main.open_camp(_main.setup.settings())
	_main.planner.run_rest()
	_main.planner.camp.injured_days = 4
	_main.planner.camp.injury_area = "body"
	_main.planner._refresh()
	_main.planner._fight.pressed.emit()
	assert_gt(_main.driver.sim.fighters[0].damage.body, 0, "he starts the fight hurt")
	_main._process(1.0)
	_main.driver.throw_towel()
	assert_string_contains(_main.result.text(), "body injury")


func test_the_setup_sound_volume_reaches_the_fight_and_m_mutes_the_strikes() -> void:
	var s: Dictionary = _main.setup.settings()
	assert_eq(s.sound_volume, 1.0, "full volume by default (D190)")
	s.sound_volume = 0.4
	_main.start_fight(s)
	assert_eq(_main.sounds.volume, 0.4)
	_press(KEY_M)
	assert_true(_main.sounds.muted)
	_press(KEY_M)
	assert_false(_main.sounds.muted)


func test_the_version_line_hides_during_the_fight_so_the_call_bar_has_the_corner() -> void:
	var version: Label = _main.get_node("UI/Version")
	assert_true(version.visible, "on the setup")
	_start()
	assert_false(version.visible, "in the fight")
	_main._back_to_setup()
	assert_true(version.visible, "back on the setup")


func test_esc_and_main_menu_go_back_to_the_title_from_the_setup() -> void:
	_main.quick_fight()
	_press(KEY_ESCAPE)
	assert_true(_main.title.visible)
	_main.quick_fight()
	_main.setup.menu_pressed.emit()
	assert_true(_main.title.visible)
	assert_false(_main.setup.visible)


func test_a_new_career_is_saved_and_opens_on_the_hub() -> void:
	_main.show_title()
	_main.title.press("New career")
	assert_true(_main.new_career.visible)
	_main.new_career.set_field("name", "Danny Hill")
	_main.new_career.press_start()
	assert_true(_main.hub.visible)
	assert_false(_main.new_career.visible)
	assert_eq(_main.career.fighter_name(), "Danny Hill")
	assert_eq(_main.career.age(), 16)
	assert_eq(_main.career_slot, 0)
	assert_eq(CareerSaves.info(0, SAVE_DIR).name, "Danny Hill", "saved as soon as it starts")


func test_run_this_week_moves_the_career_on_and_saves_it() -> void:
	_main.open_new_career()
	_main.new_career.press_start()
	_main.hub.press_week()
	assert_eq(_main.career.week, 1)
	assert_eq(int(CareerSaves.info(0, SAVE_DIR).week), 1, "every week is saved")
	assert_string_contains(_main.hub.text(), "Mon 11 Jan 2027")


func test_continue_picks_the_career_back_up_where_it_was() -> void:
	_main.open_new_career()
	_main.new_career.set_field("name", "Danny Hill")
	_main.new_career.press_start()
	_main.hub.press_week()
	_main.hub.title_pressed.emit()
	assert_true(_main.title.visible)
	assert_true(_main.title.can_continue())
	_main.career = null
	_main.title.press("Continue")
	assert_true(_main.hub.visible)
	assert_eq(_main.career.fighter_name(), "Danny Hill")
	assert_eq(_main.career.week, 1)


func test_load_career_lists_the_slots_and_loads_one() -> void:
	_main.open_new_career()
	_main.new_career.set_field("name", "First Man")
	_main.new_career.press_start()
	_main.open_new_career()
	_main.new_career.set_field("name", "Second Man")
	_main.new_career.press_start()
	assert_eq(_main.career_slot, 1, "a second career takes the next slot")
	_main.show_title()
	_main.title.press("Load career")
	assert_true(_main.load_screen.visible)
	assert_string_contains(_main.load_screen.text(), "First Man")
	assert_string_contains(_main.load_screen.text(), "Second Man")
	_main.load_screen.load_pressed.emit(0)
	assert_eq(_main.career.fighter_name(), "First Man")
	assert_true(_main.hub.visible)
