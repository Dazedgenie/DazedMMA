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


func test_with_the_debug_overlay_on_any_fight_can_pause_step_a_tick_and_go_quarter_speed() -> void:
	_start()
	_main._process(FRAME)
	_press(KEY_F3)
	_press(KEY_P)
	assert_true(_main.driver.paused, "F3 on: P pauses on any difficulty (D477)")
	var at: int = _main.driver.sim.now
	_press(KEY_PERIOD)
	for n in 10:
		_main._process(FRAME)
	assert_eq(_main.driver.sim.now, at + 1, ". steps one tick")
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	event.shift_pressed = true
	_main._unhandled_input(event)
	assert_eq(_main.driver.speed, FightDriver.QUARTER, "Shift+Space: quarter speed")
	_press(KEY_F3)
	_press(KEY_P)
	assert_false(_main.driver.paused, "it can always be unpaused")


func test_the_wheel_zooms_the_fight_camera_and_c_puts_it_back() -> void:
	_start()
	_main._process(FRAME)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_main._unhandled_input(wheel)
	assert_true(_main.arena.free_cam.held, "the wheel takes the camera (D473)")
	assert_lt(_main.arena.free_cam.zoom, 1.0, "in closer")
	_press(KEY_C)
	assert_false(_main.arena.free_cam.held, "C gives it back")


func test_a_right_drag_turns_the_fight_camera() -> void:
	_start()
	_main._process(FRAME)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	_main._input(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(120.0, 0.0)
	_main._input(move)
	assert_true(_main.arena.free_cam.held, "dragging took the camera (D473)")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	_main._input(release)
	var swing: float = _main.arena.free_cam.swing
	_main._input(move)
	assert_eq(_main.arena.free_cam.swing, swing, "let go, moving the mouse doesn't turn it")


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


func test_the_setups_gameplan_goes_into_the_fight_and_can_change_at_the_break() -> void:
	_main.setup.gameplan.show_plan({ "approach": "pressure", "where": "wrestle_heavy" })
	assert_eq(_main.setup.settings().gameplan, { "approach": "pressure", "target": "", "where": "wrestle_heavy" })
	_start()
	var sim: FightSim = _main.driver.sim
	_main._process(FRAME)
	assert_eq(sim.decisions[0].gameplan.label, "Pressure · Take him down")
	assert_eq(sim.decisions[1].gameplan.label, "Legs", "the Kicker's corner gives him his style's plan (D324)")
	assert_string_contains(FightHud.plan_text(sim, 0), "Pressure · Take him down")
	_main.driver.speed = FightDriver.FAST
	var frames: int = 0
	while _main.state != _main.ROUND_BREAK and not sim.is_over() and frames < 20000:
		frames += 1
		_main._process(FRAME)
	if sim.is_over():
		pass_test("finished in the first round")
		return
	assert_eq(_main._break_plan.picked(), { "approach": "pressure", "target": "", "where": "wrestle_heavy" }, "the break shows the plan")
	_main._break_plan.show_plan({ "target": "body" })
	_main._start_next_round()
	_main._process(FRAME)
	_main._process(FRAME)
	assert_eq(sim.decisions[0].gameplan.label, "Body", "changed at the break")


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


func test_the_version_line_shows_only_on_the_title_and_load_screens() -> void:
	var version: Label = _main.get_node("UI/Version")
	assert_true(version.visible, "on the title the game opens on")
	_main.quick_fight()
	assert_false(version.visible, "not on the setup: it sat on its keys line (D431)")
	_start()
	assert_false(version.visible, "in the fight")
	_main._back_to_setup()
	assert_false(version.visible, "back on the setup")
	_main.show_title()
	assert_true(version.visible, "on the title")
	_main.open_load()
	assert_true(version.visible, "on the load screen")


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
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	assert_true(_main.hub.visible)
	assert_false(_main.new_career.visible)
	assert_eq(_main.career.fighter_name(), "Danny Hill")
	assert_eq(_main.career.age(), 16)
	assert_eq(_main.career_slot, 0)
	assert_eq(CareerSaves.info(0, SAVE_DIR).name, "Danny Hill", "saved as soon as it starts")


func test_a_new_career_plays_his_childhood_first_and_back_keeps_the_choices() -> void:
	_main.open_new_career()
	_main.new_career.set_field("name", "Danny Hill")
	_main.new_career.press_start()
	assert_true(_main.childhood.visible, "Play his childhood is on by default")
	assert_false(_main.hub.visible)
	_main.childhood.back_pressed.emit()
	assert_true(_main.new_career.visible)
	assert_eq(_main.new_career.choices().name, "Danny Hill", "back keeps what he'd filled in")
	_main.new_career.press_start()
	for i in 3:
		_main.childhood.press_choice(1)
		_main.childhood.press_next()
	_main.childhood.press_start()
	assert_true(_main.gym_screen.visible, "then your gym")
	_main.gym_screen.pick(1)
	assert_string_contains(_main.gym_screen.text(), "Danny Hill")
	_main.gym_screen.press_start()
	assert_true(_main.hub.visible)
	assert_eq(_main.career.gym.name, _main.gym_screen.gyms[1].name)
	assert_eq(_main.career.fighter_name(), "Danny Hill")
	assert_eq(_main.career.childhood.picks.size(), 3)
	var shown: Dictionary = _main.childhood.he_became()
	assert_eq(_main.career.fighter.frame, shown.frame, "Who he became showed the man he is")
	assert_eq(_main.career.fighter.gifts, shown.gifts)
	assert_eq(_main.career.about.background, String(Childhood.shared().tally(_main.career.childhood.picks).background))
	assert_eq(CareerSaves.load_slot(0, SAVE_DIR).childhood.picks, _main.career.childhood.picks, "saved with him")


func test_run_this_week_moves_the_career_on_and_saves_it() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.hub.press_week()
	assert_eq(_main.career.week, 1)
	assert_eq(int(CareerSaves.info(0, SAVE_DIR).week), 1, "every week is saved")
	assert_string_contains(_main.hub.text(), "Mon 11 Jan 2027")


func test_continue_picks_the_career_back_up_where_it_was() -> void:
	_main.open_new_career()
	_main.new_career.set_field("name", "Danny Hill")
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
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
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.open_new_career()
	_main.new_career.set_field("name", "Second Man")
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	assert_eq(_main.career_slot, 1, "a second career takes the next slot")
	_main.show_title()
	_main.title.press("Load career")
	assert_true(_main.load_screen.visible)
	assert_string_contains(_main.load_screen.text(), "First Man")
	assert_string_contains(_main.load_screen.text(), "Second Man")
	_main.load_screen.load_pressed.emit(0)
	assert_eq(_main.career.fighter_name(), "First Man")
	assert_true(_main.hub.visible)


func test_advance_runs_weeks_until_something_happens_and_saves() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.career.week_plan = "time_off"
	_main.career.next_offers_week = 1000  # No offers coming (D304).
	_main.career.money = 100000  # Never short on the gym fee, so no shifts to stop on (D313).
	_main.hub.press_advance()
	assert_eq(_main.career.week, Career.ADVANCE_MAX_WEEKS, "nothing happens to a fresh 16-year-old resting for 8 weeks")
	assert_eq(int(CareerSaves.info(0, SAVE_DIR).week), Career.ADVANCE_MAX_WEEKS)
	assert_string_contains(_main.hub.text(), "The last %d weeks" % Career.ADVANCE_MAX_WEEKS)



func test_a_career_fight_goes_from_the_offer_through_the_camp_to_his_record() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.career.week_plan = "time_off"
	_main.hub.press_week()
	var offer_id: String = _main.hub.offer_ids()[0]
	var fight_week: int = int(_main.career.offer(offer_id).week)
	_main.hub.press_accept(offer_id)
	assert_false(_main.career.booked.is_empty(), "booked")
	assert_true(CareerSaves.load_slot(0, SAVE_DIR).booked.has("opponent"), "and saved")
	_main.hub.press_camp()
	var planner: CampPlanner = _main.planner
	assert_not_null(planner, "the camp planner, on his own fighter")
	assert_eq(planner.weeks, fight_week - _main.career.week + 1)
	planner.pick_preset("time_off")  # No camp injuries: the doctor clears him.
	planner.run_rest()
	assert_eq(_main.career.week, fight_week, "fight week waits for the fight")
	assert_true(planner.done())
	assert_eq(int(CareerSaves.info(0, SAVE_DIR).week), fight_week, "each camp week saved")
	assert_eq(planner.night_card.gameplan.picked(), { "approach": "", "target": "", "where": "" }, "a time-off camp told him nothing")
	planner.night_card.gameplan.pick(Gameplan.APPROACH, "counter")
	planner.fight_pressed.emit(planner.trained_profile())
	assert_eq(_main.state, _main.FIGHT)
	assert_true(bool(_main.settings.career))
	assert_eq(String(_main.settings.gameplan.approach), "counter", "tonight's plan from the fight night card (D320)")
	assert_eq(String(_main.settings.ruleset), Matchmaker.TEEN_RULES)
	_main.driver.throw_towel()
	var frames: int = 0
	while _main.state != _main.OVER and frames < 100:
		frames += 1
		_main._process(FRAME)
	assert_eq(_main.state, _main.OVER)
	assert_eq(_main.career.fights.size(), 1, "on his record")
	assert_eq(String(_main.career.fights[0].result), "loss", "the towel")
	assert_eq(String(_main.career.fights[0].method), "TKO")
	assert_eq(_main.career.week, fight_week + 1)
	assert_eq(CareerSaves.load_slot(0, SAVE_DIR).fights.size(), 1, "saved")
	assert_string_contains(_main.result.text(), "0-0-0 → 0-1-0 amateur", "what it means (D436): his record before and after")
	assert_string_contains(_main.result.text(), "Medical suspension: 30 days (a TKO loss)", "the aftermath (D305)")
	assert_eq(_main.career.suspended_days, Aftermath.TKO_DAYS - Career.FIGHT_TO_MONDAY)
	_main._career_after_fight()
	assert_true(_main.hub.visible)
	assert_string_contains(_main.hub.text(), "L vs ")


func test_film_study_in_a_career_camp_finds_his_habit_and_only_found_habits_are_cued() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.career.week_plan = "time_off"
	_main.hub.press_week()
	_main.hub.press_accept(_main.hub.offer_ids()[0])
	var him: Dictionary = _main.career.booked_opponent()
	him.tells = [{ "trigger": "own_jab_blocked", "action": "body_kick", "chance": 0.7, "within_ms": 1500 },
		{ "trigger": "opp_strike_misses", "action": "overhand", "chance": 0.5, "within_ms": 800 }]
	_main.career.trainee.stats.fight_iq = 100.0
	_main.career.coach_specialty = Coach.TACTICIAN  # Film study finds a habit 70% a session.
	_main.career.gym.rooms.video = 1  # Film study needs the video room (D442).
	_main.hub.press_camp()
	var planner: CampPlanner = _main.planner
	assert_string_contains(planner.scouting_text(), "Known:", "the scouting box (D401)")
	planner.pick_preset("time_off")
	for i in 10:
		planner.set_slot(i, "film_study")
	planner.run_rest()
	var found: Array[String] = Scouting.found(_main.career, String(him.id))
	assert_false(found.is_empty(), "a camp of film study finds a habit")
	assert_string_contains(planner.log_text(), "Film study found his habit")
	assert_string_contains(planner.scouting_text(), "Habit:")
	planner.fight_pressed.emit(planner.trained_profile())
	assert_eq(_main.state, _main.FIGHT)
	assert_eq(str(_main.settings.known_tells), str(found), "only found habits get the cue")
	assert_not_null(_main.arena.tell_watch)
	_main.driver.throw_towel()
	var frames: int = 0
	while _main.state != _main.OVER and frames < 100:
		frames += 1
		_main._process(FRAME)
	assert_eq(_main.state, _main.OVER)


func test_playing_film_study_on_the_booked_man_and_naming_his_habit_finds_it_for_sure() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.career.week_plan = "time_off"
	_main.hub.press_week()
	_main.hub.press_accept(_main.hub.offer_ids()[0])
	var him: Dictionary = _main.career.booked_opponent()
	him.tells = [{ "trigger": "own_jab_blocked", "action": "body_kick", "chance": 0.7, "within_ms": 1500 }]
	_main.career.gym.rooms.video = 1  # Film study needs the video room (D442).
	_main.hub.press_camp()
	var planner: CampPlanner = _main.planner
	planner.pick_preset("time_off")
	planner.set_slot(10, "film_study")  # Saturday morning: no school.
	planner.set_play(10, true)
	planner.run_week()
	var screen: FilmStudyScreen = planner.film
	assert_not_null(screen, "his tape opens (D410)")
	assert_true(screen.study.finds, "a habit of his left to find")
	assert_eq(Scouting.key(screen.study.habit), "own_jab_blocked>body_kick")
	screen.start()
	screen.end_tape()
	for i in screen.study.choices.size():
		if Scouting.key(screen.study.choices[i]) == Scouting.key(screen.study.habit):
			screen.name_it(i)
	screen.finish()
	assert_true(Scouting.found(_main.career, String(him.id)).has("own_jab_blocked>body_kick"), "named right: found for sure")
	assert_string_contains(planner.log_text(), "Film study found his habit")


func test_drilling_a_rule_in_a_career_camp_takes_it_into_the_fight_as_sharp_as_camp_left_it() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.career.week_plan = "time_off"
	_main.hub.press_week()
	_main.hub.press_accept(_main.hub.offer_ids()[0])
	_main.hub.press_camp()
	var planner: CampPlanner = _main.planner
	assert_string_contains(planner.rules_text(), "Rule 1: none", "the Rules box (D402)")
	assert_ne(planner.phase_text(), "", "the camp's part this week")
	planner.rule_slots.pick(1, "sprawl_on_the_shot")
	planner.rule_slots.changed.emit()
	assert_eq(_main.career.rule_slots[0], "sprawl_on_the_shot")
	planner.pick_preset("time_off")
	for i in 4:
		planner.set_slot(i, "drill_rule_1")
	planner.run_rest()
	var drilled: float = RuleDrilling.drilled(_main.career, "sprawl_on_the_shot")
	assert_gt(drilled, 0.0, "drilled in camp")
	assert_string_contains(planner.log_text(), "Drilled When he shoots → sprawl")
	planner.fight_pressed.emit(planner.trained_profile())
	assert_eq(_main.state, _main.FIGHT)
	assert_eq(_main.settings.rules, [[1, "sprawl_on_the_shot", snappedf(drilled, 0.1)]])
	_main.driver.step()  # The rule goes in with the first tick's commands.
	assert_eq(String(_main.driver.sim.decisions[0].rules.slots[0].get("rule", {}).get("id", "")), "sprawl_on_the_shot", "in the fight")
	_main.driver.throw_towel()
	var frames: int = 0
	while _main.state != _main.OVER and frames < 100:
		frames += 1
		_main._process(FRAME)
	assert_eq(_main.state, _main.OVER)


func test_the_booked_man_comes_in_with_his_camp_and_your_moves_go_on_your_record_for_the_next_one() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.career.week_plan = "time_off"
	_main.hub.press_week()
	_main.hub.press_accept(_main.hub.offer_ids()[0])
	for i in 3:
		_main.career.fights.append({ "opponent": "old_%d" % i, "result": "win", "week": 0, "moves": { "leg_kick": 15 } })
	_main.career.booked.title = "test_belt"  # Every title fight's man drills a rule against you (D404).
	var camp: Dictionary = OpponentCamp.of(_main.career)
	assert_eq(String(camp.rule), "check_the_leg_kick", "your leg kick, checked")
	_main.hub.press_camp()
	var planner: CampPlanner = _main.planner
	planner.pick_preset("time_off")
	planner.run_rest()
	planner.show_night_card(true)
	assert_string_contains(planner.night_card.text(), "HIS CAMP", "on the fight night card")
	assert_string_contains(planner.night_card.text(), "for your leg kick")
	planner.fight_pressed.emit(planner.trained_profile())
	assert_eq(_main.state, _main.FIGHT)
	assert_eq(_main.settings.their_camp, camp)
	_main.driver.step()  # His plan and rule go in with the first tick's commands.
	var his: DecisionLayer = _main.driver.sim.decisions[1]
	assert_eq(String(his.rules.slots[0].get("rule", {}).get("id", "")), "check_the_leg_kick", "his rule, in the fight")
	assert_eq(Gameplan.describe(camp.plan), Gameplan.describe(his.gameplan.parts) if his.gameplan != null else Gameplan.OWN_GAME)
	_main.driver.throw_towel()
	var frames: int = 0
	while _main.state != _main.OVER and frames < 100:
		frames += 1
		_main._process(FRAME)
	assert_eq(_main.state, _main.OVER)
	assert_true(_main.career.fights[-1].get("moves") is Dictionary, "what he threw, kept for the next man's camp")

func test_a_pro_picks_his_cut_in_camp_weighs_in_before_fight_night_and_fights_with_what_it_cost_and_won() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.career.week_plan = "time_off"
	_main.hub.press_week()
	_main.hub.press_accept(_main.hub.offer_ids()[0])
	_main.career.trainee.age_years = 21.0
	_main.career.pro = true
	_main.career.division = "lightweight"
	_main.career.fighter.frame.adult_kg = 80.0
	_main.career.booked.pro = true  # A pro fight weighs in the day before (D405).
	_main.hub.press_camp()
	var planner: CampPlanner = _main.planner
	assert_not_null(planner.cut_picker, "the cut is picked in the camp")
	planner.set_cut(WeightCut.HARD)
	assert_eq(String(_main.career.booked.cut), WeightCut.HARD)
	var weighed: Dictionary = WeightCut.of(_main.career)
	planner.pick_preset("time_off")
	planner.run_rest()
	assert_true(planner.weigh_in_card.visible, "the weigh-in comes first")
	assert_false(planner.night_card.visible)
	assert_string_contains(planner.weigh_in_card.text(), "Hard cut")
	assert_string_contains(planner.weigh_in_card.text(), "WEIGHT")
	planner.weigh_in_card.press_continue()
	assert_true(planner.night_card.visible, "then fight night")
	assert_string_contains(planner.night_card.text(), "WEIGH-IN")
	var trained: Dictionary = planner.trained_profile()
	planner.fight_pressed.emit(trained)
	assert_eq(_main.state, _main.FIGHT)
	assert_eq(String(_main.settings.weigh_in.cut), WeightCut.HARD)
	var red: Dictionary = _main.settings.red_profile
	assert_almost_eq(float(red.condition.tank), float(trained.condition.tank) * (1.0 - float(weighed.him.tank_cost)), 0.002, "the cut drains his tank")
	assert_almost_eq(float(red.stats.chin), float(trained.stats.chin) - float(weighed.him.chin_cost), 0.01)
	assert_almost_eq(float(red.stats.get("strength", FighterState.DEFAULT_STAT)),
		float(trained.stats.get("strength", FighterState.DEFAULT_STAT)) + float(weighed.edge), 0.01, "the bigger man's edge")
	_main.driver.throw_towel()
	var frames: int = 0
	while _main.state != _main.OVER and frames < 100:
		frames += 1
		_main._process(FRAME)
	assert_eq(String(_main.career.fights[-1].weigh_in.cut), WeightCut.HARD, "on his record")

func test_his_corner_names_the_habits_you_found_and_how_often_he_has_done_them_at_the_break() -> void:
	var kick := { "trigger": "own_jab_blocked", "action": "body_kick", "chance": 0.7, "within_ms": 1500 }
	var overhand := { "trigger": "opp_strike_misses", "action": "overhand", "chance": 0.5, "within_ms": 800 }
	var sim := FightSim.new(1, [FighterState.new("Red"), FighterState.new("Blue")], ActionLibrary.load_dir())
	sim.fighters[1].tells.assign([kick, overhand])
	assert_eq(_main.corner_habit_lines(sim, null), [] as Array[String], "a quick fight: no scouting, nothing said")
	var watch := Scouting.Watch.new([Scouting.key(kick)])
	var lines: Array[String] = _main.corner_habit_lines(sim, watch)
	assert_eq(lines.size(), 1, "only the habit you found (D419)")
	assert_string_contains(lines[0], "When his jab is blocked, he throws a body kick. He hasn't shown it yet")
	for n in 2:
		watch.set_off(kick, n * 100)
		watch.started("body_kick", n * 100 + 1)
	assert_string_contains(_main.corner_habit_lines(sim, watch)[0], "He's done it 2 times so far")


func test_a_quick_camp_has_no_drill_rule_sessions() -> void:
	var planner := CampPlanner.new(FighterLibrary.load_dir().profile("wrestler"))
	add_child_autofree(planner)
	assert_false(planner._session_ids.has("drill_rule_1"), "nothing to drill outside a career")
	assert_eq(planner.rules_text(), "")


func test_a_quick_fight_still_cues_every_tell() -> void:
	_main.start_fight(_main.setup.settings())
	assert_null(_main.arena.tell_watch, "no scouting outside a career")


func test_simming_a_career_fight_goes_straight_to_the_result() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.career.week_plan = "time_off"
	_main.hub.press_week()
	_main.hub.press_accept(_main.hub.offer_ids()[0])
	_main.hub.press_camp()
	var planner: CampPlanner = _main.planner
	planner.pick_preset("time_off")
	planner.run_rest()
	assert_true(planner.night_card.visible, "fight night")
	assert_string_contains(planner.night_card.text(), "Fit to fight")
	planner.night_card.press_sim()
	assert_eq(_main.state, _main.OVER, "played out at once")
	assert_true(_main.driver.sim.is_over())
	assert_eq(_main.career.fights.size(), 1)
	assert_true(bool(_main.career.fights[0].simmed))
	assert_string_contains(_main.result.text(), "Simmed")
	assert_string_contains(_main.result.text(), "Medical suspension")
	assert_eq(str(_main.result.button_labels()), str(["Back to the hub"]))


func test_a_tournament_goes_on_round_by_round_and_ends_with_a_medal() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	_main.new_career.set_know_the_game(true)  # Not the tutorial (D316): its own test below.
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	var c: Career = _main.career
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	c.offers = [c.matchmaker().make_tournament(c, rng, 4)]  # A four-man open (D315).
	_main.show_hub()
	var offer_id: String = _main.hub.offer_ids()[0]
	var fight_week: int = int(c.offer(offer_id).week)
	_main.hub.press_accept(offer_id)
	_main.hub.press_camp()
	var planner: CampPlanner = _main.planner
	planner.pick_preset("time_off")
	planner.run_rest()
	planner.fight_pressed.emit(planner.trained_profile())
	var tank_in: float = float(_main.settings.red_profile.condition.tank)
	_main.driver.sim.submit(FightCommand.throw_towel(_main.driver.sim.now, 1))  # His opponent's corner gives up.
	var frames: int = 0
	while _main.state != _main.OVER and frames < 100:
		frames += 1
		_main._process(FRAME)
	assert_eq(String(c.fights[-1].result), "win")
	assert_eq(c.week, fight_week, "the same day")
	assert_eq(c.tournament_stage(), 1)
	assert_string_contains(_main.result.text(), "Through to the final")
	assert_eq(str(_main.result.button_labels()), str(["On to the final", "Pull out"]))
	assert_eq(int(CareerSaves.load_slot(0, SAVE_DIR).booked.tournament.stage), 1, "saved between rounds")
	_main.next_tournament_fight()
	assert_eq(_main.state, _main.FIGHT, "the final, straight away")
	assert_eq(String(_main.settings.blue), String(c.booked.tournament.men[1].id))
	assert_almost_eq(float(_main.settings.red_profile.condition.tank), tank_in - Tournament.TANK_PER_FIGHT, 0.001, "tired from the semi-final")
	_main.driver.throw_towel()
	frames = 0
	while _main.state != _main.OVER and frames < 100:
		frames += 1
		_main._process(FRAME)
	assert_eq(String(c.fights[-1].result), "loss")
	assert_eq(c.week, fight_week + 1, "his day's over")
	assert_eq(String(c.medals[0].medal), Tournament.SILVER)
	assert_string_contains(_main.result.text(), "Silver medal")
	assert_eq(str(_main.result.button_labels()), str(["Back to the hub"]))
	_main._career_after_fight()
	assert_string_contains(_main.hub.text(), "Medals: silver")


func test_a_new_career_teaches_the_game_with_tips_and_a_first_fight_of_three_calls() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
	assert_true(bool(_main.new_career.choices().tutorial), "the tutorial is on unless you know the game (D316)")
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	assert_true(_main.tips.visible, "a tip card over the hub")
	assert_string_contains(_main.tips.text(), "His week")
	_main.tips.press_ok()
	assert_false(_main.tips.visible, "Got it")
	assert_true("hub" in _main.career.tips_seen)
	assert_true("hub" in CareerSaves.load_slot(0, SAVE_DIR).tips_seen, "saved")
	_main.career.week_plan = "time_off"
	_main.hub.press_week()
	assert_string_contains(_main.tips.text(), "Fight offers", "the offers' tip once they come")
	_main.tips.press_ok()
	var offer_id: String = _main.hub.offer_ids()[0]
	assert_eq(int(_main.career.offer(offer_id).lesson), 1)
	assert_string_contains(_main.hub.text(), "Coach's pick")
	_main.hub.press_accept(offer_id)
	_main.hub.press_camp()
	assert_string_contains(_main.tips.text(), "His camp")
	assert_eq(_main.tips.waiting(), 2, "and mitt work after it")
	_main.tips.press_ok()
	_main.tips.press_ok()
	var planner: CampPlanner = _main.planner
	assert_false(planner.night_card.gameplan.visible, "the gameplan opens with his third fight")
	planner.pick_preset("time_off")
	planner.run_rest()
	assert_string_contains(_main.tips.text(), "Fight night")
	_main.tips.press_ok()
	planner.fight_pressed.emit(planner.trained_profile())
	assert_eq(_main.state, _main.FIGHT)
	assert_eq(int(_main.settings.lesson), 1)
	assert_eq(_main.settings.calls, Tutorial.FIRST_CALLS)
	assert_false(bool(_main.settings.tell_cues))
	assert_true((_main.settings.gameplan as Dictionary).is_empty())
	assert_eq(_main.hud.dialog_title(), "Your first calls", "the fight waits on its tip")
	assert_true(_main.hud.is_allowed("takedown"))
	assert_false(_main.hud.is_allowed("catch_the_kick"), "Catch the kick! comes in fight 2")
	_main.driver.throw_towel()
	var frames: int = 0
	while _main.state != _main.OVER and frames < 100:
		frames += 1
		_main._process(FRAME)
	assert_eq(String(_main.career.fights[-1].result), "loss")
	assert_string_contains(_main.tips.text(), "A loss", "his first loss gets a word")
	_main.tips.press_ok()
	_main._career_after_fight()
	_main.tips.press_ok()  # Suspended: the towel's a TKO.
	_main.open_notebook()
	for title: String in ["His week", "Fight offers", "His camp", "Your first calls", "A loss"]:
		assert_string_contains(_main.tips.text(), title, "the Coach's Notebook keeps it")
	_main.tips.press_ok()
	assert_false(_main.tips.visible)
	_main.hub.press_division()
	assert_true(_main.world_page.visible, "the world pages (D432)")
	assert_eq(_main.world_page.tab, WorldScreen.DIVISION)
	assert_true(_main.world_page.shown_rows().any(func(r: Dictionary) -> bool: return String(r.cells.met) == "lost to him"),
		"the man who beat him is in the list (D352)")
	_main.world_page.close_page()
	assert_false(_main.world_page.visible)
