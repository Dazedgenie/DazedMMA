extends GutTest
## The fight screen (game/main.tscn, #19): a full 3-round fight is playable with the
## keyboard and the mouse, from the setup to the result.

const FRAME: float = 0.05

var _main: Node


func before_each() -> void:
	_main = load("res://game/main.tscn").instantiate()
	add_child_autofree(_main)


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


func test_the_screen_opens_on_the_fight_setup() -> void:
	assert_true(_main.setup.visible)
	assert_false(_main.hud.visible)
	assert_eq(_main.setup.settings().red, "wrestler", "the playtest matchup comes first")


func test_hotkeys_make_calls_and_change_the_speed() -> void:
	_start()
	_press(KEY_4)
	_press(KEY_Q)
	_main._process(FRAME)
	var calls: Array = _main.driver.sim.events.filter(func(e: FightEvent) -> bool: return e.type == FightEvent.CALL_HEARD and e.actor == 0)
	assert_eq(calls.map(func(e: FightEvent) -> String: return e.data.call_id), ["takedown", "catch_the_kick"])
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
	assert_eq(_main.hud.dialog_title(), "Fight over")
	assert_string_contains(_main.hud._dialog_body.get_parsed_text(), "cut off the cage", "how long each fighter circled and cut off (D119)")
	if sim.events[-1].data.result in [FightSim.RESULT_KO, FightSim.RESULT_TKO]:
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
	assert_eq(_main.hud.dialog_title(), "Fight over")
	assert_eq(_main.state, _main.OVER)
