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


func test_three_rounds_of_jabs_go_to_the_judges_on_tick_9000() -> void:
	var sim: FightSim = _run(SEED)
	assert_true(sim.is_over())
	assert_eq(sim.now, 9000)
	assert_eq(_count(sim, FightEvent.ROUND_ENDED), 3)
	var last: FightEvent = sim.events[-1]
	assert_eq(last.type, FightEvent.FIGHT_ENDED)
	assert_has([Judging.UNANIMOUS, Judging.SPLIT, Judging.MAJORITY, Judging.DRAW], last.data.result)
	assert_eq(last.data.cards.size(), Judging.JUDGES)
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
	# 3 x 5:00 = 900 s of fight time, so 1000x means under 900 ms. Shared CI machines
	# stall now and then, so an over-budget fight gets up to three runs and the
	# fastest counts (as in SimCheck.TIMING_TRIES): a slow sim is slow every time (D105, docs/01 §2.1).
	var fastest: float = INF
	var runs: int = 0
	while runs < 3 and fastest >= 900.0:
		var started: int = Time.get_ticks_usec()
		_run(SEED, _commands())
		fastest = minf(fastest, (Time.get_ticks_usec() - started) / 1000.0)
		runs += 1
	gut.p("Full fight simulated in %.1f ms%s" % [fastest, " (fastest of %d runs)" % runs if runs > 1 else ""])
	assert_lt(fastest, 900.0)


## Two fighters who do nothing unless told, standing at `gap` metres (default: mid range).
func _idle_pair(red: FighterState = null, blue: FighterState = null, gap: float = 1.8) -> FightSim:
	var sim := FightSim.new(SEED,
		[red if red != null else FighterState.new("Red", {}, []), blue if blue != null else FighterState.new("Blue", {}, [])],
		_actions)
	_place(sim, gap)
	return sim


func _place(sim: FightSim, gap: float, centre: Vector2 = Vector2.ZERO) -> void:
	sim.fighters[0].pos = centre + Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = centre + Vector2(gap / 2.0, 0.0)


func test_starting_a_move_costs_its_stamina() -> void:
	var sim: FightSim = _idle_pair()
	sim.submit(FightCommand.queue_action(0, 0, "body_kick"))
	sim.tick()
	assert_almost_eq(sim.fighters[0].stamina, 94.0, 0.001, "body_kick.json costs 6")
	sim.tick()
	assert_almost_eq(sim.fighters[0].stamina, 94.12, 0.001, "then breathing refills 1.2 a second")


func test_the_corner_gives_stamina_back_between_rounds() -> void:
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, []), FighterState.new("Blue", {}, [])], _actions, 2, 10)
	sim.fighters[0].stamina = 0.0
	while sim.clock.current_round == 1:
		sim.tick()
	# 10 s of breathing (12) then the corner wins back 55% of the missing 88.
	assert_almost_eq(sim.fighters[0].stamina, 12.0 + 88.0 * 0.55, 0.01)


func test_a_jab_uses_the_shared_formula_on_effective_stats() -> void:
	var sim: FightSim = _idle_pair(FighterState.new("Red", { "boxing": 70, "speed": 60 }, []))
	assert_almost_eq(sim.odds(0, "jab"), 0.65, 0.0001)
	sim.fighters[0].stamina = 0.0  # exhausted: Boxing and Speed both at −30%
	assert_almost_eq(sim.odds(0, "jab"), 0.5 + (65.0 * 0.7 - 50.0) / 100.0, 0.0001)


func test_a_hurt_defender_gets_hit_more() -> void:
	var sim: FightSim = _idle_pair()
	var fresh: float = sim.odds(0, "jab")
	sim.fighters[1].damage.head = 500
	assert_gt(sim.odds(0, "jab"), fresh)


func test_strike_events_carry_the_odds_they_were_rolled_at() -> void:
	var sim: FightSim = _idle_pair()
	sim.submit(FightCommand.queue_action(0, 0, "jab"))
	for i in 10:
		sim.tick()
	for e in sim.events:
		if e.type in [FightEvent.STRIKE_LANDED, FightEvent.STRIKE_MISSED]:
			assert_almost_eq(e.data.chance, 0.5, 0.0001)


func test_the_catch_kick_is_only_possible_while_the_opponent_is_on_one_leg() -> void:
	var sim: FightSim = _idle_pair()
	assert_eq(sim.odds(0, "catch_kick_single"), 0.0)
	sim.fighters[1].action_id = "body_kick"
	sim.fighters[1].phase = "windup"  # ONE_LEG from windup to recovery
	assert_eq(sim.active_flags(1), ["ONE_LEG"] as Array[String])
	# Base 20% + 35% for the leg + 10% for catching them mid-commitment.
	assert_almost_eq(sim.odds(0, "catch_kick_single"), 0.20 + 0.35 + FightSim.COUNTER_BONUS, 0.0001)


func test_a_sprawl_is_easier_against_a_shot_with_the_head_low() -> void:
	var sim: FightSim = _idle_pair()
	var early: float = sim.odds(1, "sprawl")
	sim.fighters[0].action_id = "double_leg"
	sim.fighters[0].phase = "active"  # HEAD_LOW from windup to active
	assert_almost_eq(sim.odds(1, "sprawl") - early, 0.10, 0.0001)
	assert_almost_eq(sim.odds(0, "double_leg"), 0.45, 0.0001)


func test_speed_shortens_telegraph_and_windup_and_fatigue_stretches_them() -> void:
	var sim: FightSim = _idle_pair(FighterState.new("Fast", { "speed": 100, "kicking": 100 }, []), FighterState.new("Slow", { "speed": 0, "kicking": 0 }, []))
	var average := FighterState.new("Average", {}, [])
	# body_kick.json: telegraph 3 ticks, windup 3, active 2.
	assert_eq(sim.phase_ticks(average, "body_kick", "telegraph"), 3)
	assert_eq(sim.phase_ticks(sim.fighters[0], "body_kick", "telegraph"), 2)
	assert_eq(sim.phase_ticks(sim.fighters[1], "body_kick", "telegraph"), 4)
	assert_eq(sim.phase_ticks(sim.fighters[0], "body_kick", "windup"), 2)
	assert_eq(sim.phase_ticks(sim.fighters[0], "body_kick", "active"), 2, "only telegraph and windup change")
	assert_eq(sim.phase_ticks(sim.fighters[0], "jab", "telegraph"), 1, "never below one tick")
	average.stamina = 0.0
	assert_eq(sim.phase_ticks(average, "double_leg", "telegraph"), 4, "an exhausted fighter telegraphs longer")


func test_an_aggressive_pace_leaning_throws_more_than_a_patient_one() -> void:
	var sim := FightSim.new(SEED, [
		FighterState.new("Aggressive", {}, ["jab"], FighterState.DEFAULT_WORK_RATE, StyleLeanings.new({ "pace": 100 })),
		FighterState.new("Patient", {}, ["jab"], FighterState.DEFAULT_WORK_RATE, StyleLeanings.new({ "pace": -100 })),
	], _actions)
	sim.run_to_end()
	assert_gt(sim.fighters[0].strikes_thrown, int(sim.fighters[1].strikes_thrown * 1.5), "the patient one still counters, so not 3×")


func test_a_grappler_leaning_shoots_more_and_a_pure_striker_never_shoots() -> void:
	var repertoire: Array[String] = ["jab", "double_leg"]
	var sim := FightSim.new(SEED, [
		FighterState.new("Grappler", {}, repertoire, FighterState.DEFAULT_WORK_RATE, StyleLeanings.new({ "base": 100 })),
		FighterState.new("Striker", {}, repertoire, FighterState.DEFAULT_WORK_RATE, StyleLeanings.new({ "base": -100 })),
	], _actions)
	sim.run_to_end()
	var shots: Array[int] = [0, 0]
	var jab_leads: int = 0
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph":
			if e.data.action_id == "double_leg":
				shots[e.actor] += 1
			elif e.actor == 0 and e.data.get("why", "") == "leads":
				jab_leads += 1
	assert_gt(shots[0], jab_leads * 3, "a +100 grappler leads with the shot (4× the weight), jabbing to counter")
	assert_eq(shots[1], 0)
