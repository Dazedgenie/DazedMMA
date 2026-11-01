extends GutTest
## Pressing the same way again and again (D258, docs/01 §22.11): the same focus call taken again within
## a minute pushes less (and costs REPEAT_STAMINA, switched off for now), and a man pressing on a call most of the last minute is read
## better by the other one.

const SEED: int = 20261101

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Red and Blue at mid range; Red is humble, so he takes every call (as in test_live_calls).
func _sim() -> FightSim:
	var red := FighterState.new("Red", {}, ["double_leg"], 0.0)
	red.profile = { "personality": { "ego": -100 } }
	var sim := FightSim.new(SEED, [red, FighterState.new("Blue", {}, [], 0.0)], _actions)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func _run(sim: FightSim, ticks: int) -> void:
	for n in ticks:
		sim.tick()


func test_pressure_again_within_a_minute_pushes_less_each_time() -> void:
	var sim: FightSim = _sim()
	var layer: DecisionLayer = sim.decisions[0]
	var ranges: Array[float] = []
	var stamina: Array[float] = []
	for n in 3:
		sim.submit(FightCommand.live_call(sim.now, 0, "pressure"))
		_run(sim, 7)
		ranges.append(layer.leaning(sim.views[0], StyleLeanings.RANGE))
		stamina.append(sim.fighters[0].stamina)
		_run(sim, 150)
	assert_almost_eq(ranges[0], 50.0, 0.01, "the first: all of it")
	assert_almost_eq(ranges[1], 50.0 * LiveCalls.REPEAT_WEAR, 0.01, "again 16 s later: 70%")
	assert_almost_eq(ranges[2], 50.0 * LiveCalls.REPEAT_WEAR * LiveCalls.REPEAT_WEAR, 0.01, "a third time: 49%")
	_run(sim, LiveCalls.REPEAT_TICKS)
	sim.submit(FightCommand.live_call(sim.now, 0, "pressure"))
	_run(sim, 7)
	assert_almost_eq(layer.leaning(sim.views[0], StyleLeanings.RANGE), 50.0, 0.01, "a minute and more later it's fresh")


func test_a_repeat_costs_only_its_repeat_stamina() -> void:
	var pressed: FightSim = _sim()
	var once: FightSim = _sim()
	pressed.submit(FightCommand.live_call(0, 0, "pressure"))
	once.submit(FightCommand.live_call(0, 0, "pressure"))
	_run(pressed, 160)
	_run(once, 160)
	pressed.submit(FightCommand.live_call(160, 0, "pressure"))
	_run(pressed, 7)
	_run(once, 7)
	assert_almost_eq(once.fighters[0].stamina - pressed.fighters[0].stamina, LiveCalls.REPEAT_STAMINA, 0.5, "REPEAT_STAMINA a repeat")


func test_pressing_on_a_call_most_of_the_last_minute_lets_the_other_man_read_him() -> void:
	var sim: FightSim = _sim()
	assert_eq(FighterAI.press_read(sim.views[1]), 0.0, "nothing to read yet")
	for n in 4:
		sim.submit(FightCommand.live_call(sim.now, 0, "pressure"))
		_run(sim, 150)
	assert_gt(sim.pressed_share(0), 0.9, "he's pressed nearly the whole minute")
	assert_almost_eq(FighterAI.press_read(sim.views[1]), FighterAI.PRESS_READ * (sim.pressed_share(0) - FighterAI.PRESS_READ_FROM) / (1.0 - FighterAI.PRESS_READ_FROM), 0.001)
	assert_eq(FighterAI.press_read(sim.views[0]), 0.0, "Blue never pressed")
	_run(sim, 400)
	assert_eq(FighterAI.press_read(sim.views[1]), 0.0, "once he's stopped for a while, it's gone")


func test_a_fight_without_calls_never_counts_anyone_pressing() -> void:
	var roster := FighterLibrary.load_dir()
	var sim := FightSim.new(SEED, roster.make_pair("pressure_wrestler", "counter_striker"), _actions, null, 60)
	sim.run_to_end()
	assert_eq(sim.pressed_share(0) + sim.pressed_share(1), 0.0, "pressing is a call's, not his style's")
