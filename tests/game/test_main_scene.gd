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
	_main.new_career.set_play_childhood(false)
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
	_main.new_career.press_start()
	_main.gym_screen.pick(0)
	_main.gym_screen.press_start()
	_main.open_new_career()
	_main.new_career.set_field("name", "Second Man")
	_main.new_career.set_play_childhood(false)
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
	planner.fight_pressed.emit(planner.trained_profile())
	assert_eq(_main.state, _main.FIGHT)
	assert_true(bool(_main.settings.career))
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
	assert_string_contains(_main.result.text(), "LOSS on his amateur record")
	assert_string_contains(_main.result.text(), "Medical suspension: 30 days (a TKO loss)", "the aftermath (D305)")
	assert_eq(_main.career.suspended_days, Aftermath.TKO_DAYS - Career.FIGHT_TO_MONDAY)
	_main._career_after_fight()
	assert_true(_main.hub.visible)
	assert_string_contains(_main.hub.text(), "L vs ")


func test_simming_a_career_fight_goes_straight_to_the_result() -> void:
	_main.open_new_career()
	_main.new_career.set_play_childhood(false)
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
