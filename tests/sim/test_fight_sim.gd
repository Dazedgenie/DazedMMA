extends GutTest
## FightSim core: tick loop, seeded randomness, commands in, events out,
## deterministic replay (docs/01-fight-engine.md §2, issue #12).

const SEED: int = 20261023

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _fighters() -> Array[FighterState]:
	return [
		FighterState.new("Red", { "boxing": 60, "speed": 55, "striking_defense": 50 }),
		FighterState.new("Blue", { "boxing": 50, "speed": 50, "striking_defense": 55 }),
	]


func _commands() -> Array[FightCommand]:
	return [
		FightCommand.queue_action(50, 0, "body_kick"),
		FightCommand.queue_action(120, 1, "double_leg"),
		FightCommand.queue_action(3100, 0, "jab"),
		FightCommand.queue_action(4000, 1, "spinning_backfist"),
	]


func _run(fight_seed: int, commands: Array[FightCommand] = []) -> FightSim:
	var sim := FightSim.new(fight_seed, _fighters(), _actions)
	for c in commands:
		sim.submit(c)
	sim.run_to_end()
	return sim


func _count(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> int:
	var n: int = 0
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			n += 1
	return n


func test_same_seed_and_command_log_replays_an_identical_fight() -> void:
	var original: FightSim = _run(SEED, _commands())
	var replayed: FightSim = FightSim.replay(SEED, _fighters(), _actions, original.command_log_as_dicts())
	assert_gt(original.events.size(), 100, "expected a busy fight to compare")
	assert_eq(JSON.stringify(replayed.events_as_dicts()), JSON.stringify(original.events_as_dicts()))
	assert_eq(replayed.fighters[0].damage, original.fighters[0].damage)
	assert_eq(replayed.fighters[1].damage, original.fighters[1].damage)


func test_command_log_survives_a_round_trip_through_json() -> void:
	var original: FightSim = _run(SEED, _commands())
	var saved: Variant = JSON.parse_string(JSON.stringify(original.command_log_as_dicts()))
	var replayed: FightSim = FightSim.replay(SEED, _fighters(), _actions, saved)
	assert_eq(JSON.stringify(replayed.events_as_dicts()), JSON.stringify(original.events_as_dicts()))


func test_a_different_seed_gives_a_different_fight() -> void:
	assert_ne(JSON.stringify(_run(SEED).events_as_dicts()), JSON.stringify(_run(SEED + 1).events_as_dicts()))


func test_a_different_command_log_gives_a_different_fight() -> void:
	assert_ne(JSON.stringify(_run(SEED).events_as_dicts()), JSON.stringify(_run(SEED, _commands()).events_as_dicts()))


func test_two_fighters_trade_jabs_with_no_commands() -> void:
	var sim: FightSim = _run(SEED)
	for i in 2:
		assert_gt(sim.fighters[i].strikes_thrown, 20, "%s should keep throwing" % sim.fighters[i].name)
		assert_gt(sim.fighters[i].strikes_landed, 0, "%s should land some" % sim.fighters[i].name)
		assert_lt(sim.fighters[i].strikes_landed, sim.fighters[i].strikes_thrown, "%s should miss some" % sim.fighters[i].name)
	assert_gt(sim.fighters[1].damage.head, 0, "jabs should hurt the head")


func test_three_rounds_end_with_a_time_decision_on_tick_9000() -> void:
	var sim: FightSim = _run(SEED)
	assert_true(sim.is_over())
	assert_eq(sim.now, 9000)
	assert_eq(_count(sim, FightEvent.ROUND_ENDED), 3)
	var last: FightEvent = sim.events[-1]
	assert_eq(last.type, FightEvent.FIGHT_ENDED)
	assert_eq(last.data.result, "time")
	assert_eq(last.round_number, 3)


func test_a_body_kick_walks_through_all_four_phases_on_its_data_timings() -> void:
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, []), FighterState.new("Blue", {}, [])], _actions)
	sim.submit(FightCommand.queue_action(10, 0, "body_kick"))
	for i in 30:
		sim.tick()
	var seen: Array = []
	for e in sim.events:
		if e.actor == 0 and e.type in [FightEvent.ACTION_PHASE, FightEvent.ACTION_ENDED]:
			seen.append([e.tick, e.data.get("phase", "ended")])
	# body_kick.json: telegraph 300, windup 300, active 200, recovery 400 ms.
	assert_eq(seen, [[10, "telegraph"], [13, "windup"], [16, "active"], [18, "recovery"], [22, "ended"]])


func test_an_active_strike_either_lands_or_misses_exactly_once() -> void:
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, []), FighterState.new("Blue", {}, [])], _actions)
	sim.submit(FightCommand.queue_action(0, 0, "jab"))
	for i in 10:
		sim.tick()
	assert_eq(_count(sim, FightEvent.STRIKE_LANDED, 0) + _count(sim, FightEvent.STRIKE_MISSED, 0), 1)


func test_bad_commands_are_rejected_with_a_reason_and_still_logged() -> void:
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, []), FighterState.new("Blue", {}, [])], _actions)
	sim.submit(FightCommand.queue_action(0, 0, "spinning_backfist"))
	sim.submit(FightCommand.queue_action(0, 5, "jab"))
	sim.tick()
	var reasons: Array = []
	for e in sim.events:
		if e.type == FightEvent.COMMAND_REJECTED:
			reasons.append(e.data.reason)
	assert_eq(reasons, ["unknown action", "unknown fighter"])
	assert_eq(sim.command_log.size(), 2)
	assert_true(sim.fighters[0].is_free())


func test_commands_for_ticks_already_played_are_refused() -> void:
	var sim := FightSim.new(SEED, _fighters(), _actions)
	for i in 5:
		sim.tick()
	assert_false(sim.submit(FightCommand.queue_action(3, 0, "jab")))
	assert_true(sim.submit(FightCommand.queue_action(5, 0, "jab")))


func test_every_event_reaches_listeners_in_order() -> void:
	var sim := FightSim.new(SEED, _fighters(), _actions)
	var heard: Array[FightEvent] = []
	sim.event_emitted.connect(func(e: FightEvent) -> void: heard.append(e))
	sim.run_to_end()
	assert_eq(heard.size(), sim.events.size())
	assert_eq(heard[-1], sim.events[-1])


func test_a_full_fight_runs_over_1000x_faster_than_fight_time() -> void:
	var started: int = Time.get_ticks_usec()
	_run(SEED, _commands())
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	# 3 x 5:00 = 900 s of fight time, so 1000x means under 900 ms.
	gut.p("Full fight simulated in %.1f ms" % elapsed_ms)
	assert_lt(elapsed_ms, 900.0)
