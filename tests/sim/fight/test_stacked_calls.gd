extends GutTest
## Two focus calls at once (docs/01 §22.14, D485–D487): Pressure! and Cut the cage! both on, a third replacing
## the oldest, and a call that pulls the other way on a leaning (Circle out! after Pressure!) replacing the older one.

const SEED: int = 20261105

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Red (humble, so he never ignores a call) and Blue standing at mid range.
func _sim() -> FightSim:
	var red := FighterState.new("Red", {}, [], 0.0)
	red.profile = { "personality": { "ego": -100 } }
	var sim := FightSim.new(SEED, [red, FighterState.new("Blue", {}, [], 0.0)], _actions)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func _run(sim: FightSim, ticks: int) -> void:
	for n in ticks:
		sim.tick()


## The calls Red is fighting to, oldest first.
func _on(sim: FightSim) -> Array[String]:
	var out: Array[String] = []
	for f: Dictionary in sim.decisions[0].calls.focuses:
		out.append(String(f.call.id))
	return out


func _answers(sim: FightSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.type == FightEvent.CALL_ANSWERED and e.actor == 0:
			out.append(e.data)
	return out


func test_pressure_and_cut_the_cage_are_both_on_at_once() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	sim.submit(FightCommand.live_call(10, 0, "cut_the_cage"))
	_run(sim, 25)
	assert_eq(_on(sim), ["pressure", "cut_the_cage"] as Array[String], "Kyle's example: both stack (D485)")
	var calls: LiveCalls = sim.decisions[0].calls
	var pressure: Dictionary = sim.calls.get_call("pressure").focus.leanings
	var cut: Dictionary = sim.calls.get_call("cut_the_cage").focus.leanings
	assert_almost_eq(calls.adjust_leaning(sim.views[0], "range", 0.0), float(pressure.range + cut.range), 0.001, "their pushes add up")
	assert_almost_eq(calls.cut_focus(), float(sim.calls.get_call("cut_the_cage").focus.cut), 0.001, "and he cuts off the cage")
	for a: Dictionary in _answers(sim):
		assert_ne(a.outcome, LiveCalls.REPLACED, "nothing replaced")


func test_each_runs_out_on_its_own_clock() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	sim.submit(FightCommand.live_call(50, 0, "cut_the_cage"))
	_run(sim, 160)
	assert_eq(_on(sim), ["cut_the_cage"] as Array[String], "Pressure!'s 15 s is up, Cut the cage! has 5 s to go")
	_run(sim, 60)
	assert_eq(_on(sim), [] as Array[String])


func test_a_third_replaces_the_oldest() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	sim.submit(FightCommand.live_call(35, 0, "cut_the_cage"))
	sim.submit(FightCommand.live_call(70, 0, "finish_him"))
	_run(sim, 70)
	sim.fighters[1].rocked_ticks = 40  # Blue rocked: Finish him! works.
	_run(sim, 20)
	assert_eq(_on(sim), ["cut_the_cage", "finish_him"] as Array[String], "two at most: Pressure! went (Kyle, D485)")
	var replaced: Array[Dictionary] = _answers(sim).filter(func(a: Dictionary) -> bool: return a.outcome == LiveCalls.REPLACED)
	assert_eq(replaced.size(), 1)
	assert_eq(replaced[0].call_id, "pressure")


func test_a_call_pulling_the_other_way_replaces_the_one_it_pulls_against() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	sim.submit(FightCommand.live_call(35, 0, "circle_out"))
	_run(sim, 50)
	assert_eq(_on(sim), ["circle_out"] as Array[String], "Circle out! after Pressure!: the corner changed its mind (Kyle, D486)")
	var replaced: Array[Dictionary] = _answers(sim).filter(func(a: Dictionary) -> bool: return a.outcome == LiveCalls.REPLACED)
	assert_eq(replaced.size(), 1)
	assert_eq(replaced[0].call_id, "pressure")
	assert_true(LiveCalls.pulls_against(sim.calls.get_call("survive"), sim.calls.get_call("finish_him")))
	assert_false(LiveCalls.pulls_against(sim.calls.get_call("pressure"), sim.calls.get_call("cut_the_cage")))
	assert_false(LiveCalls.pulls_against(sim.calls.get_call("hand_fight"), sim.calls.get_call("survive")), "no leanings: nothing to pull against")


func test_the_same_call_again_starts_it_afresh_and_keeps_the_other() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "cut_the_cage"))
	sim.submit(FightCommand.live_call(35, 0, "pressure"))
	sim.submit(FightCommand.live_call(70, 0, "cut_the_cage"))
	_run(sim, 90)
	assert_eq(_on(sim), ["pressure", "cut_the_cage"] as Array[String], "Cut the cage! again: its 15 s starts over, Pressure! stays on")


func test_the_fight_screen_names_both() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "pressure"))
	sim.submit(FightCommand.live_call(10, 0, "cut_the_cage"))
	_run(sim, 25)
	var state: String = FightHud.call_state(sim, 0)
	assert_string_contains(state, "Pressure!")
	assert_string_contains(state, "Cut the cage!")
