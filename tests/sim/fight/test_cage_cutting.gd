extends GutTest
## Cutting the cage (D230, docs/01 §20.5): the Cage cutting stat, aiming at the exit instead of
## following, the cut-off fighter's answers (reversing, planting and countering), herding with a
## feint, and the Cut the cage! call.

const SEED: int = 20261030

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _presser(cage_cutting: int = 50) -> FighterState:
	return FighterState.new("Presser", { "cage_cutting": cage_cutting }, ["jab"], 0.0, StyleLeanings.new({ "range": 100 }))


func _statue(p_stats: Dictionary = {}) -> FighterState:
	return FighterState.new("Statue", p_stats, [], 0.0)


func _sim(red: FighterState, blue: FighterState, red_at: Vector2, blue_at: Vector2) -> FightSim:
	var sim := FightSim.new(SEED, [red, blue], _actions)
	sim.fighters[0].pos = red_at
	sim.fighters[1].pos = blue_at
	return sim


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		sim.tick()


func test_a_good_cage_cutter_starts_cutting_further_from_the_fence() -> void:
	# The statue 2.8 m out from the middle: past a great cutter's reach, short of a poor one's.
	var great := _sim(_presser(90), _statue(), Vector2(1.6, 1.6), Vector2(2.8, 0.0))
	_ticks(great, 10)
	assert_gt(great.cutting_ticks[0], 0, "Cage cutting 90 reaches %.2f m out" % (FightSim.CUT_FROM - FightSim.CUT_EARLY * 0.8))
	var poor := _sim(_presser(30), _statue(), Vector2(1.6, 1.6), Vector2(2.8, 0.0))
	_ticks(poor, 10)
	assert_eq(poor.cutting_ticks[0], 0, "Cage cutting 30 only cuts closer to the fence")


func test_the_cut_works_by_cage_cutting_against_the_opponents_footwork() -> void:
	var sticky := _sim(_presser(80), _statue({ "footwork": 30 }), Vector2(2.6, 1.2), Vector2(3.8, 0.0))
	var slippery := _sim(_presser(30), _statue({ "footwork": 80 }), Vector2(2.6, 1.2), Vector2(3.8, 0.0))
	_ticks(sticky, 5)
	_ticks(slippery, 5)
	assert_lt(absf(sticky.fighters[0].pos.y), absf(slippery.fighters[0].pos.y),
		"a good cutter against poor feet gets across to the line from the opponent to the middle sooner")


func test_cutting_off_he_leads_the_way_the_opponent_is_drifting() -> void:
	# A Kicker drifting round the fence one way: the cutter steps to the side he's going.
	var roster := FighterLibrary.load_dir()
	var pair: Array[FighterState] = roster.make_pair("boxer", "kicker")
	var sim := _sim(pair[0], pair[1], Vector2(1.8, 0.0), Vector2(3.9, 0.0))
	sim.fighters[1].pos = Vector2(3.9, 0.0)
	# Pretend the Kicker has been sliding up the fence (+y) for a while.
	sim._strides[1] = Vector2(0.0, 0.08)
	sim._drift[0] = Vector2(0.0, 0.08)
	var before: float = sim.fighters[0].pos.y
	sim._move(0, 1.85, 0.0, 1.0)
	assert_gt(sim.fighters[0].pos.y, before, "he steps toward the exit the Kicker is heading for, not behind him")


func test_cutting_he_shuts_the_exit_before_closing_the_distance() -> void:
	# The statue's way out is down the fence (−y), away from the presser: he steps across toward it.
	var sim := _sim(_presser(80), _statue(), Vector2(2.0, 1.5), Vector2(3.8, 0.0))
	var from: Vector2 = sim.fighters[0].pos
	var gap: float = from.distance_to(sim.fighters[1].pos)
	var toward: Vector2 = (sim.fighters[1].pos - from).normalized()
	sim._move(0, 1.2, 0.0, 1.0)
	var moved: Vector2 = sim.fighters[0].pos - from
	assert_almost_eq(moved.length(), sim.step_length(0), 0.001, "a full step, as always")
	assert_lt(moved.y, toward.y * sim.step_length(0), "the step leans toward the open exit, more than walking straight at him")
	assert_lt(sim.fighters[0].pos.distance_to(sim.fighters[1].pos), gap, "and it still closes in")


func test_the_cutter_steps_where_the_best_way_out_is_worth_least() -> void:
	var routes := EscapeRoutes.new()
	routes.walk(Vector2(3.8, 0.0), 0.15, Vector2.ZERO)
	var shut: float = routes.best_worth(Vector2(2.8, -0.6), 0.15)
	var open: float = routes.best_worth(Vector2(2.8, 1.2), 0.15)
	assert_lt(shut, open, "standing on the side he'd run to leaves him less than standing off to the other side")
	assert_true(routes.any_open(Vector2(1.0, 2.5), 0.15), "far off, he has a way out")
	assert_false(routes.any_open(Vector2(3.0, 0.0), 0.15), "right in front of him on the fence, every way out is in reach")


func test_routes_back_into_the_fence_dont_count_as_ways_out() -> void:
	var routes := EscapeRoutes.new()
	routes.walk(Vector2(3.8, 0.0), 0.15, Vector2.ZERO)
	for h in EscapeRoutes.HEADINGS:
		if routes.headings[h].x > 0.5:
			assert_false(routes.usable[h], "heading %s goes back into the fence" % routes.headings[h])


func test_the_cut_the_cage_call_cuts_off_the_exits_in_open_space() -> void:
	# The statue 2 m out: no cutter's own reach gets there, the call's does.
	var plain := _sim(_presser(50), _statue(), Vector2(0.5, 1.5), Vector2(2.0, 0.0))
	_ticks(plain, 20)
	assert_eq(plain.cutting_ticks[0], 0, "no call: open space, no cut")
	var called := _sim(_presser(50), _statue(), Vector2(0.5, 1.5), Vector2(2.0, 0.0))
	called.decisions[0].calls.focus = { "call": CallLibrary.shared().get_call("cut_the_cage"), "until": 1000 }
	var feet: FeetPlan = called.decisions[0].plan_feet(called.views[0])
	assert_true(feet.anywhere, "Cut the cage! cuts from anywhere")
	assert_eq(feet.cut, 1.0, "all he can")
	_ticks(called, 20)
	assert_gt(called.cutting_ticks[0], 0, "the call has him cutting the statue off out in the open")


func test_the_cut_the_cage_call_is_a_fifteen_second_focus_on_r() -> void:
	var call: Dictionary = CallLibrary.shared().get_call("cut_the_cage")
	assert_eq(LiveCalls.shape(call), LiveCalls.FOCUS)
	assert_eq(call.hotkey, "R")
	assert_eq(int(call.focus.duration_ms), 15000)
	assert_eq(call.positions, ["standing"])


func test_a_cut_off_fighter_turns_back_the_way_that_is_still_open() -> void:
	# The Kicker by the fence, circling up it (+y) into the Boxer, who has that side shut.
	var roster := FighterLibrary.load_dir()
	var turned: int = 0
	for s in 20:
		var pair: Array[FighterState] = roster.make_pair("boxer", "kicker")
		var sim := FightSim.new(SEED + s, pair, _actions)
		sim.fighters[0].pos = Vector2(1.9, 0.6)
		sim.fighters[1].pos = Vector2(3.9, 0.0)
		sim._circle_sign[1] = -1.0  # Round the Boxer toward +y.
		var ai: FighterAI = sim.decisions[1].ai
		for n in 30:
			sim._cut_at[0] = sim.now
			sim._routes_at[0] = -1000
			var toward: Vector2 = (sim.fighters[1].pos - sim.fighters[0].pos).normalized()
			sim._cut_step(0, toward, sim.fighters[0].pos.distance_to(sim.fighters[1].pos), sim.step_length(0))
			sim.views[1].now = sim.now
			assert_eq(sim.way_out(1), 1, "his way out is back down the fence")
			var feet: FeetPlan = sim.decisions[1].plan_feet(sim.views[1])
			if ai._reverse_until > sim.now:
				assert_eq(feet.way, 1, "he goes back the way that's open")
				turned += 1
				break
			sim.now += 1
		if sim.way_out(1) != 1:
			break
	assert_gt(turned, 0, "now and then, before the door shuts")


func test_a_cut_off_fighter_is_readier_to_meet_him_coming_in() -> void:
	assert_gt(FighterAI.INTERCEPT_CUT_OFF, 0.0, "plant and counter")


func test_a_fighter_bitten_on_a_feint_plants_his_feet() -> void:
	var sim := _sim(_statue(), _statue(), Vector2(-1.0, 0.0), Vector2(1.0, 0.0))
	var from: Vector2 = sim.fighters[0].pos
	sim.fighters[0].bit_ticks = 5
	sim._move(0, 3.0, 0.0)
	assert_almost_eq((sim.fighters[0].pos - from).length(), sim.step_length(0) * FightSim.BIT_FEET, 0.001,
		"weight back and hands up: %d%% of a step" % roundi(FightSim.BIT_FEET * 100.0))


func test_a_cutter_herds_a_circling_fighter_with_a_feint() -> void:
	var roster := FighterLibrary.load_dir()
	var herded: int = 0
	for s in 40:
		var pair: Array[FighterState] = roster.make_pair("pressure_wrestler", "kicker")
		var sim := FightSim.new(SEED + s, pair, _actions)
		sim.fighters[0].pos = Vector2(2.0, 0.0)
		sim.fighters[1].pos = Vector2(3.9, 0.0)
		var ai: FighterAI = sim.decisions[0].ai
		for n in 20:
			sim._cut_at[0] = sim.now
			sim.views[0].now = sim.now
			sim._circling[1] = 1.0
			var d: Decision = ai._herd(sim.views[0])
			if d != null:
				assert_eq(d.action_id, FightSim.FEINT)
				herded += 1
				break
			sim.now += 1
	assert_gt(herded, 0, "a cutter feints to plant him by the fence")
	var open := FightSim.new(SEED, roster.make_pair("pressure_wrestler", "kicker"), _actions)
	open.fighters[0].pos = Vector2(-1.0, 0.0)
	open.fighters[1].pos = Vector2(0.9, 0.0)
	open._cut_at[0] = open.now
	open._circling[1] = 1.0
	for n in 50:
		assert_null(open.decisions[0].ai._herd(open.views[0]), "nothing to herd him into in the middle")


func test_the_time_he_cut_the_opponent_off_onto_the_fence_is_counted() -> void:
	var roster := FighterLibrary.load_dir()
	var sim := FightSim.new(SEED, roster.make_pair("pressure_wrestler", "counter_striker"), _actions, 1, 300)
	sim.run_to_end()
	assert_gt(sim.cut_offs[0], 0, "the Pressure wrestler walks him onto the fence now and then")
	assert_gte(sim.cut_offs[0], sim.cut_offs[1], "more than the Counter-striker does to him")


# --- Escape routes and being shut in (D233, D234, docs/01 §20.6) -------------------

## A Boxer right in front of the opponent on the fence, his routes read: every way out shut.
func _shut_in(red_id: String, blue_id: String, s: int = 0) -> FightSim:
	var roster := FighterLibrary.load_dir()
	var sim := FightSim.new(SEED + s, roster.make_pair(red_id, blue_id), _actions)
	sim.fighters[0].pos = Vector2(2.9, 0.0)
	sim.fighters[1].pos = Vector2(3.9, 0.0)
	_read_routes(sim)
	return sim


func _read_routes(sim: FightSim) -> void:
	sim._cut_at[0] = sim.now
	sim._routes_at[0] = -1000
	var gap: Vector2 = sim.fighters[1].pos - sim.fighters[0].pos
	sim._cut_step(0, gap.normalized(), gap.length(), sim.step_length(0))
	sim.views[1].now = sim.now
	sim.views[0].now = sim.now


func test_shut_in_each_style_has_its_own_answer() -> void:
	var answers := { "kicker": FighterAI.ANSWER_BURST, "counter_striker": FighterAI.ANSWER_BURST,
		"boxer": FighterAI.ANSWER_PLANT, "brawler": FighterAI.ANSWER_PLANT,
		"wrestler": FighterAI.ANSWER_TIE_UP, "pressure_wrestler": FighterAI.ANSWER_TIE_UP, "muay_thai": FighterAI.ANSWER_TIE_UP }
	for id: String in answers:
		var sim := _shut_in("boxer", id)
		assert_true(sim.is_shut_in(1), "%s: every way out shut" % id)
		var layer: DecisionLayer = sim.decisions[1]
		assert_eq(layer.ai.shut_in_answer(sim.views[1], layer), answers[id], id)


func test_a_shut_in_outside_fighter_bursts_out_round_him() -> void:
	var burst: int = 0
	for s in 10:
		var sim := _shut_in("boxer", "kicker", s)
		for n in 60:
			_read_routes(sim)
			var feet: FeetPlan = sim.decisions[1].plan_feet(sim.views[1])
			if feet.burst:
				assert_eq(feet.circle, 1.0, "round him, all he can")
				assert_eq(feet.way, sim.burst_way(1), "the least shut way")
				burst += 1
				break
			sim.now += 1
	assert_gt(burst, 5, "most of the time inside six seconds (Fight IQ makes it likelier)")


func test_bursting_out_is_quicker_but_poor_feet_barely_are() -> void:
	var even := _sim(_statue(), _statue({ "footwork": 50 }), Vector2(-1.0, 0.0), Vector2(1.0, 0.0))
	var poor := _sim(_statue(), _statue({ "footwork": 10 }), Vector2(-1.0, 0.0), Vector2(1.0, 0.0))
	for sim: FightSim in [even, poor]:
		var from: Vector2 = sim.fighters[1].pos
		sim._move(1, 3.0, 1.0, 0.0, 1, false, true)
		var ratio: float = (sim.fighters[1].pos - from).length() / sim.step_length(1)
		if sim == even:
			assert_almost_eq(ratio, 1.0 + FightSim.BURST_EXTRA, 0.01, "even feet: %d%% quicker" % roundi(FightSim.BURST_EXTRA * 100.0))
		else:
			assert_lt(ratio, 1.0 + FightSim.BURST_EXTRA * 0.2, "Footwork 10 against 50: barely quicker")
		assert_true(sim.is_bursting(1))


func test_a_cutter_catches_some_bursts_with_a_strike() -> void:
	var caught: int = 0
	for s in 40:
		var sim := _shut_in("pressure_wrestler", "kicker", s)
		sim.fighters[0].pos = Vector2(2.4, 0.0)
		sim._burst_at[1] = sim.now
		var d: Decision = sim.decisions[0].ai._catch_burst(sim.views[0], sim.decisions[0])
		if d != null:
			assert_eq(sim.actions.get_action(d.action_id).category, FighterAI.STRIKE)
			caught += 1
		assert_null(sim.decisions[0].ai._catch_burst(sim.views[0], sim.decisions[0]), "one read a burst")
	assert_between(caught, 4, 30, "about Cage cutting 75 × %.1f of them" % FighterAI.CATCH_RATE)


func test_a_shut_in_grappler_ties_him_up() -> void:
	var tied: int = 0
	for s in 20:
		var sim := _shut_in("boxer", "wrestler", s)
		sim.fighters[0].pos = Vector2(2.7, 0.0)
		for n in 60:
			_read_routes(sim)
			var d: Decision = sim.decisions[1].ai._shut_in_tie_up(sim.views[1], sim.decisions[1])
			if d != null:
				assert_eq(d.action_id, FighterAI.CLINCH_ENTRY)
				tied += 1
				break
			sim.now += 1
	assert_gt(tied, 10, "inside six seconds, nearly every time")
	var striker := _shut_in("boxer", "kicker")
	for n in 100:
		assert_null(striker.decisions[1].ai._shut_in_tie_up(striker.views[1], striker.decisions[1]), "a Kicker doesn't")


func test_a_shut_in_striker_plants_his_feet() -> void:
	var sim := _shut_in("pressure_wrestler", "boxer")
	var feet: FeetPlan = sim.decisions[1].plan_feet(sim.views[1])
	assert_eq(feet.circle, 0.0, "the Boxer stops circling and fights")
	assert_false(feet.burst)


func test_once_every_way_is_shut_the_cutter_holds_the_inside_line() -> void:
	var sim := _shut_in("boxer", "kicker")
	sim.fighters[1].pos = Vector2(3.9, -0.6)  # The Kicker slides down the fence.
	var toward: Vector2 = (sim.fighters[1].pos - sim.fighters[0].pos).normalized()
	var across: Vector2 = sim._cut_step(0, toward, 1.0, sim.step_length(0))
	assert_lt(across.y, 0.0, "the Boxer slides with him, staying between him and the middle")


func test_being_shut_in_and_what_cutting_cost_are_counted() -> void:
	var roster := FighterLibrary.load_dir()
	var shut: int = 0
	var hurt: int = 0
	var escaped: int = 0
	var kicker_shut: int = 0
	for s in 3:
		var sim := FightSim.new(SEED + s, roster.make_pair("boxer", "kicker"), _actions)
		sim.run_to_end()
		shut += sim.shut_in_ticks[1]
		hurt += sim.cut_damage_taken[0]
		escaped += sim.cage_escapes[1]
		assert_lte(sim.cage_escapes[1], sim.cut_offs[0], "he can't get out more times than he was trapped")
		kicker_shut += sim.shut_in_ticks[0]
	# Hardly ever the other way round: a Kicker pressing forward can walk the Boxer onto the fence for a
	# moment (2 ticks in these fights since the corners take turns stepping first, D253).
	assert_lt(kicker_shut * 20, shut, "the Kicker hardly ever shuts the Boxer in (%d ticks against %d)" % [kicker_shut, shut])
	assert_gt(shut, 0, "the Boxer shuts the Kicker in now and then")
	assert_gt(hurt, 0, "and the Kicker makes him pay for walking him down")
	assert_gt(escaped, 0, "and the Kicker gets back to the middle")
