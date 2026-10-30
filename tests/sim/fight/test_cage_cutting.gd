extends GutTest
## Cutting the cage (D230, docs/01 §20.4): the Cage cutting stat, aiming at the exit instead of
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
	var sim := _sim(_presser(80), _statue(), Vector2(2.0, 1.5), Vector2(3.8, 0.0))
	var from: Vector2 = sim.fighters[0].pos
	var gap: float = from.distance_to(sim.fighters[1].pos)
	sim._move(0, 1.2, 0.0, 1.0)
	var moved: Vector2 = sim.fighters[0].pos - from
	assert_almost_eq(moved.length(), sim.step_length(0), 0.001, "a full step, as always")
	var toward: Vector2 = (sim.fighters[1].pos - from).normalized()
	assert_gt(absf(moved.dot(Vector2(-toward.y, toward.x))), absf(moved.dot(toward)) * 0.5,
		"a diagonal step: a good part of it goes across, not straight at him")
	assert_lt(sim.fighters[0].pos.distance_to(sim.fighters[1].pos), gap, "and it still closes in")


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


func test_a_cut_off_fighter_turns_back_the_other_way() -> void:
	# The Kicker circling by the fence with the Boxer cutting him off from the inside.
	var roster := FighterLibrary.load_dir()
	var turned: int = 0
	for s in 20:
		var pair: Array[FighterState] = roster.make_pair("boxer", "kicker")
		var sim := FightSim.new(SEED + s, pair, _actions)
		sim.fighters[0].pos = Vector2(1.9, 0.0)
		sim.fighters[1].pos = Vector2(3.9, 0.0)
		sim._cut_at[0] = 0
		var ai: FighterAI = sim.decisions[1].ai
		for n in 30:
			sim._cut_at[0] = sim.now
			sim.views[1].now = sim.now
			var way: int = sim.circle_sign(1)
			var feet: FeetPlan = sim.decisions[1].plan_feet(sim.views[1])
			if ai._reverse_until > sim.now:
				assert_eq(feet.way, -way, "he goes back the way he came")
				turned += 1
				break
			sim.now += 1
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
