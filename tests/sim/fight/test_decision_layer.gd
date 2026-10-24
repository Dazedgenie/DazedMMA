extends GutTest
## DecisionLayer: one priority stack for what a fighter starts (docs/01 §6.0,
## docs/12 §3 item 2, issue #33): commands, then live calls, then drilled rules,
## then the fighter's own AI, with gameplans tilting the AI's weights.

const SEED: int = 20261024

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters standing at mid range. Red works at `work_rate` with `repertoire`; Blue does nothing.
func _sim(repertoire: Array[String] = [], work_rate: float = 0.0, rules: Variant = null) -> FightSim:
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, repertoire, work_rate), FighterState.new("Blue", {}, [], 0.0)], _actions, rules)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func _starts(sim: FightSim, actor: int = 0) -> Array[String]:
	var out: Array[String] = []
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph" and e.actor == actor:
			out.append(e.data.action_id)
	return out


func _answers(sim: FightSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.type == FightEvent.CALL_ANSWERED:
			out.append(e.data)
	return out


func test_the_placeholder_ai_lives_outside_the_fight_sim() -> void:
	var sim: FightSim = _sim()
	assert_true(sim.decisions[0].ai is PlaceholderAI)
	assert_false(sim.has_method("choice_weight"), "action choice belongs to the decision layer")
	assert_false(sim.has_method("idle_work_rate"))


func test_a_queued_command_beats_the_fighters_own_choice() -> void:
	var sim: FightSim = _sim(["jab"], 1.0)  # The AI would jab every free tick.
	sim.submit(FightCommand.queue_action(0, 0, "teep"))
	sim.tick()
	assert_eq(_starts(sim), ["teep"] as Array[String])
	assert_eq(sim.fighters[0].queued_action_id, "", "the command is used up once it starts")


func test_a_live_call_waits_out_the_call_delay_in_fight_time() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.live_call(0, 0, "teep"))
	for n in LiveCalls.BASE_DELAY_TICKS:
		sim.tick()
	assert_eq(_starts(sim), [] as Array[String], "still processing the call")
	sim.tick()
	assert_eq(_starts(sim), ["teep"] as Array[String])
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers.size(), 1)
	assert_eq(answers[0].outcome, LiveCalls.ACCEPTED)


func test_an_accepted_call_beats_the_ai_but_not_a_queued_command() -> void:
	var sim: FightSim = _sim(["jab"], 1.0)
	sim.submit(FightCommand.live_call(0, 0, "body_kick"))
	sim.submit(FightCommand.queue_action(LiveCalls.BASE_DELAY_TICKS, 0, "teep"))
	sim.run_to_end()
	var starts: Array[String] = _starts(sim)
	var teep_at: int = starts.find("teep")
	assert_gt(teep_at, -1)
	assert_eq(starts[teep_at + 1], "body_kick", "the call goes next, ahead of the AI's jabs")


func test_a_call_the_fighter_cannot_do_is_logged_with_the_reason() -> void:
	var no_takedowns := Ruleset.load_id("pro")
	no_takedowns.allows.takedowns = false
	var sim: FightSim = _sim([], 0.0, no_takedowns)
	sim.submit(FightCommand.live_call(0, 0, "double_leg"))
	for n in 10:
		sim.tick()
	assert_eq(_starts(sim), [] as Array[String])
	var answers: Array[Dictionary] = _answers(sim)
	assert_eq(answers.size(), 1)
	assert_eq(answers[0].outcome, LiveCalls.INFEASIBLE)
	assert_string_contains(answers[0].reason, "not allowed")


func test_a_refused_call_falls_through_to_the_fighters_own_choice() -> void:
	var sim: FightSim = _sim(["jab"], 1.0)
	sim.decisions[0].calls = _Stubborn.new()
	sim.decisions[0].sources = []
	sim.decisions[0].add_source(sim.decisions[0].calls)
	sim.submit(FightCommand.live_call(0, 0, "teep"))
	for n in 30:
		sim.tick()
	assert_false(_starts(sim).has("teep"))
	assert_true(_starts(sim).has("jab"))
	assert_eq(_answers(sim)[0].outcome, LiveCalls.IGNORED)
	assert_eq(_answers(sim)[0].reason, "doesn't trust the corner")


func test_live_calls_replay_from_the_command_log() -> void:
	var sim := FightSim.new(SEED, _busy_pair(), _actions)
	sim.submit(FightCommand.live_call(30, 0, "body_kick"))
	sim.submit(FightCommand.live_call(200, 1, "double_leg"))
	sim.run_to_end()
	var again: FightSim = FightSim.replay(SEED, _busy_pair(), _actions, sim.command_log_as_dicts())
	assert_eq(_answers(sim).size(), 2)
	assert_eq(JSON.stringify(again.events_as_dicts()), JSON.stringify(sim.events_as_dicts()))


func _busy_pair() -> Array[FighterState]:
	return [FighterState.new("Red", {}, ["jab", "teep"], 0.05), FighterState.new("Blue", {}, ["jab"], 0.05)]


func test_a_gameplan_tilts_the_ais_weights_without_choosing_for_it() -> void:
	var sim: FightSim = _sim(["jab", "double_leg"], 0.3)
	sim.decisions[0].add_source(Gameplan.new({ "takedown": 0.0 }))
	sim.run_to_end()
	var starts: Array[String] = _starts(sim)
	assert_gt(starts.size(), 50)
	assert_false(starts.has("double_leg"), "a no-takedown plan zeroes the shot's weight")


func test_an_action_id_in_a_gameplan_beats_its_category() -> void:
	var plan := Gameplan.new({ "strike": 0.5, "jab": 3.0 })
	var view := FightView.new(_sim(), 0)
	assert_eq(plan.adjust_weight(view, _actions.get_action("jab"), 1.0), 3.0)
	assert_eq(plan.adjust_weight(view, _actions.get_action("cross"), 1.0), 0.5)
	assert_eq(plan.adjust_weight(view, _actions.get_action("double_leg"), 1.0), 1.0)


class _Stubborn extends LiveCalls:
	func refusal(_view: FightView, _call: Dictionary) -> String:
		return "doesn't trust the corner"
