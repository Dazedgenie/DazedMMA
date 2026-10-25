extends GutTest
## CageMap: the temporary top-down debug view of the cage (D106, docs/01 §20.1).

const SEED: int = 20261025

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _map() -> CageMap:
	var map := CageMap.new()
	map.size = Vector2(780, 1000)
	add_child_autofree(map)
	return map


func _play(sim: FightSim, ticks: int, map: CageMap = null) -> void:
	for n in ticks:
		sim.tick()
		if map != null:
			map.sample()
			map.header_lines()


func test_each_trail_follows_its_fighter_and_keeps_only_the_last_four_seconds() -> void:
	var sim := FightSim.new(SEED, SimCheck.showcase_fighters(), _actions)
	var map: CageMap = _map()
	map.watch(sim)
	_play(sim, 100, map)
	for i in 2:
		assert_eq(map.trail(i).size(), CageMap.TRAIL_TICKS + 1)
		assert_eq(map.trail(i)[map.trail(i).size() - 1], sim.fighters[i].pos)


func test_the_trails_start_again_when_a_new_round_begins() -> void:
	var sim := FightSim.new(SEED, SimCheck.showcase_fighters(), _actions, 3, 10)
	var map: CageMap = _map()
	map.watch(sim)
	_play(sim, 103, map)
	assert_eq(sim.clock.current_round, 2)
	assert_lt(map.trail(0).size(), 5, "the walk back to the corners isn't drawn as movement")


func test_pace_is_metres_per_second_over_the_last_half_second() -> void:
	var sim := FightSim.new(SEED, SimCheck.showcase_fighters(), _actions)
	var map: CageMap = _map()
	map.watch(sim)
	_play(sim, 30, map)
	var t: PackedVector2Array = map.trail(0)
	var expected: Vector2 = (t[t.size() - 1] - t[t.size() - 1 - CageMap.SPEED_WINDOW]) * 2.0
	assert_almost_eq(map.velocity(0).x, expected.x, 0.0001)
	assert_almost_eq(map.velocity(0).y, expected.y, 0.0001)
	assert_lt(map.velocity(0).length(), 2.5, "nobody walks faster than 2 m/s")


func test_the_header_names_both_fighters_and_the_range() -> void:
	var sim := FightSim.new(SEED, SimCheck.showcase_fighters(), _actions)
	var map: CageMap = _map()
	map.watch(sim)
	_play(sim, 50, map)
	var lines: Array[String] = map.header_lines()
	assert_string_contains(lines[0], sim.fighters[0].name)
	assert_string_contains(lines[0], "wants")
	assert_string_contains(lines[0], "cutting off")
	assert_string_contains(lines[1], sim.fighters[1].name)
	assert_string_contains(lines[2], "m apart")


func test_watching_a_fight_never_changes_it() -> void:
	var watched := FightSim.new(SEED, SimCheck.showcase_fighters(), _actions)
	var plain := FightSim.new(SEED, SimCheck.showcase_fighters(), _actions)
	var map: CageMap = _map()
	map.watch(watched)
	_play(watched, 1500, map)
	_play(plain, 1500)
	assert_eq(JSON.stringify(watched.events_as_dicts()), JSON.stringify(plain.events_as_dicts()))
	assert_eq(watched.fighters[0].pos, plain.fighters[0].pos)


func test_the_console_shows_the_live_fight_on_the_cage_view() -> void:
	var console := DebugConsole.new()
	console.echo_to_output = false
	add_child_autofree(console)
	assert_true(console._cage_map.visible, "the cage view is on by default")
	assert_null(console._cage_map.sim)
	console._toggle_live()
	assert_eq(console._cage_map.sim, console._live_sim)
	console._process(1.0)
	assert_eq(console._cage_map.trail(0).size(), 21, "the start plus 20 ticks (1 s at 2x)")
	console._cage_toggle.button_pressed = false
	assert_false(console._cage_map.visible)
