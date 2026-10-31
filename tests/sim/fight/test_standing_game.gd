extends GutTest
## The standing game (issue #13, docs/01-fight-engine.md §3, §5, §8): distance
## bands, the cage, flag counters, rocked / knockdown / KO and round scoring.

const SEED: int = 20261024

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _sim(red: FighterState, blue: FighterState, rounds: int = 1, round_seconds: int = 300) -> FightSim:
	return FightSim.new(SEED, [red, blue], _actions, rounds, round_seconds)


func _idle(fighter_name: String, p_stats: Dictionary = {}) -> FighterState:
	return FighterState.new(fighter_name, p_stats, [], 0.0)


func _place(sim: FightSim, red: Vector2, blue: Vector2) -> void:
	sim.fighters[0].pos = red
	sim.fighters[1].pos = blue


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


func _ticks(sim: FightSim, n: int) -> void:
	for i in n:
		sim.tick()


# --- Distance -----------------------------------------------------------------

func test_fighters_start_out_of_range_and_walk_into_punching_range() -> void:
	var sim: FightSim = _sim(FighterState.new("Red"), FighterState.new("Blue"))
	assert_eq(sim.band(), Octagon.BAND_OUT)
	_ticks(sim, 30)
	assert_has([Octagon.BAND_MID, Octagon.BAND_POCKET], sim.band())
	assert_gt(_events(sim, FightEvent.RANGE_CHANGED).size(), 0)


func test_a_jab_thrown_from_out_of_range_falls_short() -> void:
	var sim: FightSim = _sim(_idle("Red"), _idle("Blue"))
	sim.submit(FightCommand.queue_action(0, 0, "jab"))
	_ticks(sim, 5)
	var missed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_MISSED, 0)
	assert_eq(missed.size(), 1)
	assert_eq(missed[0].data.reason, "out of range")


func test_the_ai_only_throws_what_reaches_from_where_it_stands() -> void:
	# Blue never throws but likes it close, so a hook that starts in the pocket stays there.
	var sim: FightSim = _sim(FighterState.new("Hooker", {}, ["hook"], 0.5),
		FighterState.new("Blue", {}, [], 0.0, StyleLeanings.new({ "range": 100, "pace": 100 })))
	_ticks(sim, 300)
	assert_gt(_events(sim, FightEvent.STRIKE_LANDED, 0).size() + _events(sim, FightEvent.STRIKE_MISSED, 0).size(), 5)
	for e in _events(sim, FightEvent.STRIKE_MISSED, 0):
		assert_false(e.data.has("reason"), "a hook was thrown from outside the pocket")


func test_a_range_fighter_keeps_further_away_than_a_pressure_fighter() -> void:
	var sim: FightSim = _sim(
		FighterState.new("Outside", {}, ["jab"], 0.0, StyleLeanings.new({ "range": -100 })),
		FighterState.new("Inside", {}, ["jab"], 0.0, StyleLeanings.new({ "range": 100, "pace": 100 })))
	assert_gt(sim.preferred_distance(0), sim.preferred_distance(1) + 0.9)


# --- The cage -------------------------------------------------------------------

func test_backing_onto_the_fence_gets_you_pinned_with_your_back_to_the_cage() -> void:
	var sim: FightSim = _sim(_idle("Red"), _idle("Blue"))
	_place(sim, Vector2(2.9, 0.0), Vector2(4.1, 0.0))
	assert_eq(sim.cage_proximity(1), Octagon.CAGE_PINNED)
	assert_has(sim.active_flags(1), "BACK_TO_CAGE")
	assert_eq(sim.cage_proximity(0), Octagon.CAGE_NEAR)


func test_better_footwork_gets_off_the_fence_sooner() -> void:
	# The mover starts pinned, the presser in front of them cutting off the way out (D107), over
	# four fights each: 30 s, 4 × 300 ticks.
	var pinned: Array[int] = []
	for footwork in [20, 50, 90]:
		var ticks: int = 0
		for n in 4:
			var sim := FightSim.new(SEED + n, [
				FighterState.new("Presser", { "footwork": 50 }, ["hook"], 0.0, StyleLeanings.new({ "range": 100, "pace": 100 })),
				FighterState.new("Mover", { "footwork": footwork }, ["head_kick"], 0.0, StyleLeanings.new({ "range": -100 }))], _actions)
			_place(sim, Vector2(2.7, 0.0), Vector2(3.9, 0.0))
			for i in 300:
				sim.tick()
				if sim.cage_proximity(1) == Octagon.CAGE_PINNED:
					ticks += 1
		pinned.append(ticks)
	# Poor feet stay trapped a good while. Less than when red always stepped first (most of the
	# 30 s): taking turns (D253) sometimes gives him two steps in a row to slip out on.
	assert_gt(pinned[0], 150, "Footwork 20 against 50 stays trapped a good while: %s" % [pinned])
	assert_gt(pinned[0], 5 * pinned[1], "far longer than even feet: %s" % [pinned])
	assert_lt(pinned[1], 200, "even feet get out: %s" % [pinned])
	assert_lte(pinned[2], pinned[1], "and better feet get out at least as fast: %s" % [pinned])


func test_even_feet_get_all_of_a_chase_and_worse_feet_a_lot_less() -> void:
	assert_eq(FightSim.footwork_edge(0.5), 1.0)
	assert_almost_eq(FightSim.footwork_edge(0.3), 0.36, 0.0001, "the Boxer's Footwork 50 against the Kicker's 70")
	assert_eq(FightSim.footwork_edge(0.7), 1.0)


# --- Flags and counters (each flag's bonus, issue #13 "done when") --------------

func test_takedown_during_body_kick_gets_bonus() -> void:
	var sim: FightSim = _sim(_idle("Red"), _idle("Blue"))
	_place(sim, Vector2(-0.9, 0.0), Vector2(0.9, 0.0))
	var balanced: float = sim.odds(0, "catch_kick_single")
	sim.fighters[1].action_id = "body_kick"
	sim.fighters[1].phase = "windup"
	assert_eq(balanced, 0.0, "the catch-kick needs a kick to catch")
	assert_almost_eq(sim.odds(0, "catch_kick_single"), 0.10 + 0.15 + FightSim.COUNTER_BONUS, 0.0001)


func test_each_flag_opens_its_counter() -> void:
	# [opponent's action, phase, flag it sets, counter action, data bonus]
	var cases: Array = [
		["body_kick", "active", "ONE_LEG", "cross", 0.15],
		["hook", "active", "LEANING", "hook", 0.15],
		["double_leg", "active", "HEAD_LOW", "knee", 0.25],
		["double_leg", "active", "HEAD_LOW", "sprawl", 0.10],
	]
	for c: Array in cases:
		var sim: FightSim = _sim(_idle("Red"), _idle("Blue"))
		_place(sim, Vector2(-0.6, 0.0), Vector2(0.6, 0.0))
		var before: float = sim.odds(0, c[3])
		sim.fighters[1].action_id = c[0]
		sim.fighters[1].phase = c[1]  # active: not a counter window, so only the flag counts
		assert_has(sim.active_flags(1), c[2])
		assert_almost_eq(sim.odds(0, c[3]) - before, c[4], 0.0001, "%s against %s" % [c[3], c[2]])


func test_an_exhausted_fighter_drops_their_hands_for_the_head_kick() -> void:
	var sim: FightSim = _sim(_idle("Red"), _idle("Blue"))
	_place(sim, Vector2(-1.0, 0.0), Vector2(1.0, 0.0))
	var fresh: float = sim.odds(0, "head_kick")
	sim.fighters[1].stamina = sim.fighters[1].max_stamina() * 0.2
	assert_has(sim.active_flags(1), "HANDS_LOW")
	assert_gt(sim.odds(0, "head_kick"), fresh + 0.19)


func test_the_double_leg_is_easier_against_the_cage() -> void:
	var sim: FightSim = _sim(_idle("Red"), _idle("Blue"))
	_place(sim, Vector2(-0.6, 0.0), Vector2(0.6, 0.0))
	var open: float = sim.odds(0, "double_leg")
	_place(sim, Vector2(2.9, 0.0), Vector2(4.1, 0.0))
	assert_almost_eq(sim.odds(0, "double_leg") - open, 0.15, 0.0001)


func test_catching_someone_in_their_recovery_is_a_counter() -> void:
	var sim: FightSim = _sim(_idle("Red"), _idle("Blue"))
	_place(sim, Vector2(-0.9, 0.0), Vector2(0.9, 0.0))
	var neutral: float = sim.odds(0, "jab")
	sim.fighters[1].action_id = "jab"
	sim.fighters[1].phase = "recovery"
	assert_true(sim.is_counter(0))
	assert_almost_eq(sim.odds(0, "jab") - neutral, FightSim.COUNTER_BONUS, 0.0001)


# --- Rocked, knockdowns, finishes -------------------------------------------------

func test_a_jab_never_rocks_a_fresh_fighter_but_a_head_kick_can() -> void:
	var sim: FightSim = _sim(_idle("Red"), _idle("Blue"))
	assert_eq(sim.rock_chance(sim.head_shock(0, 3)), 0.0)
	assert_gt(sim.rock_chance(sim.head_shock(0, 12)), 0.0)


func test_damage_and_a_weak_chin_make_a_rock_more_likely() -> void:
	var sim: FightSim = _sim(_idle("Red"), _idle("Blue", { "chin": 80 }))
	var fresh: float = sim.rock_chance(sim.head_shock(0, 8))
	sim.fighters[1].damage.head = 600
	assert_gt(sim.rock_chance(sim.head_shock(0, 8)), fresh)
	var glass: FightSim = _sim(_idle("Red"), _idle("Blue", { "chin": 10 }))
	assert_gt(glass.rock_chance(glass.head_shock(0, 8)), fresh)


func test_a_rocked_fighter_defends_worse_and_gets_out_of_there() -> void:
	var sim: FightSim = _sim(FighterState.new("Red"), FighterState.new("Blue"))
	var calm: float = sim.fighters[1].effective_stat("striking_defense")
	sim.fighters[1].rocked_ticks = 30
	assert_almost_eq(sim.fighters[1].effective_stat("striking_defense"), calm * 0.7, 0.001)
	assert_has(sim.active_flags(1), "HANDS_LOW")
	assert_gt(sim.preferred_distance(1), Octagon.LONG_WITHIN)
	assert_eq(sim.preferred_distance(0), Octagon.BAND_CENTRES[Octagon.BAND_POCKET], "the other fighter swarms")


func test_power_shots_on_a_glass_chin_finish_the_fight_early() -> void:
	var sim: FightSim = _sim(
		FighterState.new("Puncher", { "power": 100, "boxing": 90 }, ["hook", "cross"], 0.3),
		_idle("Glass", { "chin": 0, "heart": 0, "composure": 100 }))
	sim.run_to_end()
	var end: FightEvent = sim.events[-1]
	assert_has([FightSim.RESULT_KO, FightSim.RESULT_TKO], end.data.result)
	assert_eq(end.data.winner, 0)
	assert_lt(sim.now, 3000, "should be over inside the round")
	assert_gt(_events(sim, FightEvent.ROCKED, 1).size(), 0)


func test_a_knocked_down_fighter_is_left_alone_until_they_get_up() -> void:
	var sim: FightSim = _sim(FighterState.new("Red", {}, ["jab"], 1.0), _idle("Blue", { "heart": 100 }))
	_place(sim, Vector2(-0.9, 0.0), Vector2(0.9, 0.0))
	sim.fighters[1].down_ticks = FightSim.DOWN_TICKS
	_ticks(sim, FightSim.DOWN_TICKS - 1)
	assert_eq(sim.fighters[0].strikes_thrown, 0)
	assert_true(sim.fighters[1].is_down())
	sim.tick()
	assert_false(sim.fighters[1].is_down())
	assert_eq(_events(sim, FightEvent.GOT_UP, 1).size(), 1)


# --- Scoring --------------------------------------------------------------------

func test_a_round_where_only_one_fighter_lands_goes_to_them_on_every_card() -> void:
	var sim: FightSim = _sim(FighterState.new("Busy", {}, ["jab"], 0.1), FighterState.new("Statue", {}, [], 0.0), 1, 60)
	sim.run_to_end()
	var rounds: Array[FightEvent] = _events(sim, FightEvent.ROUND_ENDED)
	assert_eq(rounds.size(), 1)
	for card: Array in rounds[0].data.cards:
		assert_eq(card[0], 10)
		assert_lt(card[1], 10)
	assert_eq(sim.events[-1].data.result, Judging.UNANIMOUS)
	assert_eq(sim.events[-1].data.winner, 0)


func test_fighters_go_back_to_their_corners_between_rounds() -> void:
	var sim: FightSim = _sim(FighterState.new("Red"), FighterState.new("Blue"), 2, 10)
	while sim.clock.current_round == 1:
		sim.tick()
	assert_eq(sim.fighters[0].pos, FightSim.START_POSITIONS[0])
	assert_eq(sim.fighters[1].pos, FightSim.START_POSITIONS[1])
