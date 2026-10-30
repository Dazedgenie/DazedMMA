extends GutTest
## The fighter AI (docs/01 §7, §20, issue #14): what a fighter does with no calls.
## Reads with reaction time, timed counters, tells and set-ups, the range plan, and
## the Kicker and Boxer fighting in character.

const SEED: int = 20261024

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim(red: FighterState, blue: FighterState, gap: float = 1.85, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [red, blue], _actions)
	sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	return sim


func _statue(fighter_name: String = "Statue", p_stats: Dictionary = {}) -> FighterState:
	return FighterState.new(fighter_name, p_stats, [], 0.0)


func _ai(sim: FightSim, i: int = 0) -> FighterAI:
	return sim.decisions[i].ai


## Telegraph events (a move starting) for one fighter: [{tick, action_id, why}].
func _starts(sim: FightSim, actor: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.events:
		if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph" and e.actor == actor:
			out.append({ "tick": e.tick, "action_id": e.data.action_id, "why": String(e.data.get("why", "")) })
	return out


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		sim.tick()


# --- Never the impossible ---------------------------------------------------------

func test_a_fighter_with_no_moves_or_no_work_rate_never_starts_anything() -> void:
	var sim: FightSim = _sim(FighterState.new("Lazy", {}, ["jab", "cross"], 0.0), _statue())
	_ticks(sim, 600)
	assert_eq(_starts(sim, 0).size(), 0, "a work rate of 0 is a statue")
	assert_eq(_starts(sim, 1).size(), 0, "so is a fighter with no moves")


func test_fighters_never_catch_a_kick_on_their_own() -> void:
	# Kyle, #14: the catch-kick only happens when the coach calls it or a drilled rule fires.
	var catcher := FighterState.new("Catcher", { "fight_iq": 100 }, ["jab", "catch_kick_single"], 0.05)
	var kicker := FighterState.new("Kicker", {}, ["body_kick"], 0.08, StyleLeanings.new({ "range": -100 }))
	var sim: FightSim = _sim(catcher, kicker)
	_ticks(sim, 3000)
	var kicks: int = 0
	for s in _starts(sim, 1):
		kicks += 1 if s.action_id == "body_kick" else 0
	assert_gt(kicks, 10, "there were kicks to catch")
	for s in _starts(sim, 0):
		assert_ne(s.action_id, "catch_kick_single", "caught a kick unprompted at tick %d" % s.tick)


func test_a_fighter_whose_kick_gets_caught_throws_it_less() -> void:
	# #18: the Kicker doesn't keep feeding a kick the opponent keeps catching.
	var counts := func(caught: int) -> Dictionary:
		var kicker := FighterState.new("Kicker", {}, ["body_kick", "teep"], 0.3, StyleLeanings.new({ "range": -100 }))
		var sim: FightSim = _sim(_statue(), kicker, 2.4)
		for n in caught:
			sim._emit(FightEvent.ACTION_PHASE, 1, { "action_id": "body_kick", "phase": "telegraph" })
			sim._emit(FightEvent.GRAPPLE_WON, 0, { "action_id": "catch_kick_single", "result": "success" })
		_ticks(sim, 3000)
		var out := { "body_kick": 0, "teep": 0 }
		for s in _starts(sim, 1):
			out[s.action_id] = out.get(s.action_id, 0) + 1
		return out
	var fresh: Dictionary = counts.call(0)
	var twice: Dictionary = counts.call(2)
	var share := func(c: Dictionary) -> float: return float(c.body_kick) / (c.body_kick + c.teep)
	assert_gt(fresh.body_kick, 20, "kicks to compare: %s" % [fresh])
	assert_lt(share.call(twice), share.call(fresh) * 0.6, "caught twice: about a quarter as keen (%s vs %s)" % [twice, fresh])
	assert_gt(twice.teep, fresh.teep, "the teep takes up the slack")


func test_every_choice_says_why() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	_ticks(sim, 1500)
	for i in 2:
		assert_gt(_starts(sim, i).size(), 5)
		for s in _starts(sim, i):
			assert_ne(s.why, "", "%s at tick %d has no reason" % [s.action_id, s.tick])


# --- Reading the opponent ------------------------------------------------------

func test_a_read_registers_one_reaction_time_after_the_move_is_first_seen() -> void:
	var sim: FightSim = _sim(FighterState.new("Reader", { "fight_iq": 100, "speed": 50 }, ["jab"], 0.0001), _statue())
	sim.fighters[1].action_id = "jab"
	sim.fighters[1].phase = "telegraph"
	sim.fighters[1].phase_ticks_left = 1
	var ai: FighterAI = _ai(sim)
	var seen := 0
	for k in 200:
		var e := FightEvent.new(k, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "jab", "phase": "telegraph" })
		ai.on_event(sim.views[0], e, sim.decisions[0])
		# Blue steps after Red each tick, so Red first sees Blue's move the tick after it starts.
		assert_eq(ai._opp.notice, k + 1 + sim.fighters[0].reaction_ticks())
		seen += 1 if ai._opp.read else 0
	# (0.15 + 0.5 × Fight IQ 100 / 100) × a 1-tick telegraph (−20%) = 52%.
	assert_almost_eq(seen / 200.0, 0.52, 0.1)
	var blue: FighterAI = _ai(sim, 1)
	blue.on_event(sim.views[1], FightEvent.new(7, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "jab", "phase": "telegraph" }), sim.decisions[1])
	assert_eq(blue._opp.notice, 7 + sim.fighters[1].reaction_ticks(), "Blue sees Red's move the tick it starts")


func test_a_fighter_wises_up_to_shots_and_clinch_entries_repeated_within_a_minute() -> void:
	# D114 (Kyle's pick): each grappling start seen in the last 60 s makes the next easier to read.
	var sim: FightSim = _sim(FighterState.new("Reader", {}, ["jab"], 0.0001), _statue())
	var ai: FighterAI = _ai(sim)
	var start := func(tick: int, id: String) -> void:
		sim.fighters[1].action_id = id
		sim.fighters[1].phase = "telegraph"
		sim.fighters[1].phase_ticks_left = 2
		ai.on_event(sim.views[0], FightEvent.new(tick, 1, FightEvent.ACTION_PHASE, 1, { "action_id": id, "phase": "telegraph" }), sim.decisions[0])
	assert_eq(ai.wise_bonus(0), 0.0, "the first shot is a surprise")
	start.call(0, "double_leg")
	start.call(100, "clinch_entry")
	start.call(150, "jab")
	assert_almost_eq(ai.wise_bonus(200), 2 * FighterAI.WISE_READ, 0.001, "a jab doesn't count")
	start.call(200, "double_leg")
	start.call(300, "double_leg")
	assert_almost_eq(ai.wise_bonus(400), FighterAI.WISE_MAX, 0.001, "four in a minute: capped")
	assert_almost_eq(ai.wise_bonus(750), 2 * FighterAI.WISE_READ, 0.001, "the first two are over a minute old")
	assert_eq(ai.wise_bonus(2000), 0.0)


func test_a_longer_telegraph_and_a_higher_fight_iq_are_read_more_often() -> void:
	var reads: Array[int] = []
	for iq in [20, 90]:
		var sim: FightSim = _sim(FighterState.new("Reader", { "fight_iq": iq }, ["jab"], 0.0001), _statue())
		var ai: FighterAI = _ai(sim)
		var n := 0
		for k in 400:
			sim.fighters[1].action_id = "head_kick"
			sim.fighters[1].phase = "telegraph"
			sim.fighters[1].phase_ticks_left = 4 if k % 2 == 0 else 1
			ai.on_event(sim.views[0], FightEvent.new(k, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "head_kick", "phase": "telegraph" }), sim.decisions[0])
			n += 1 if ai._opp.read else 0
		reads.append(n)
	assert_gt(reads[1], reads[0] * 2, "Fight IQ 20 vs 90 reads: %s" % [reads])


func test_counters_are_timed_to_land_while_the_opponent_is_committed() -> void:
	# A sharp counter-puncher against a slugger who loads up on hooks in the pocket.
	var counters: int = 0
	for n in 4:
		var sim: FightSim = _sim(FighterState.new("Counter", { "fight_iq": 100, "boxing": 70 }, ["jab", "cross"]),
			FighterState.new("Slugger", {}, ["hook"], 0.06, StyleLeanings.new({ "range": 100 })), 1.2, SEED + n)
		_ticks(sim, 1500)
		# Tick a move started → the bonus it was timed to catch: "counter" for a counter,
		# the flag for an opening ("opening: LEANING").
		var chosen: Dictionary = {}
		for s in _starts(sim, 0):
			if s.why.begins_with("counters"):
				chosen[s.tick] = "counter"
			elif s.why.begins_with("opening: "):
				chosen[s.tick] = s.why.trim_prefix("opening: ")
		var started: int = -1
		for e in sim.events:
			if e.actor != 0:
				continue
			if e.type == FightEvent.ACTION_PHASE and e.data.phase == "telegraph":
				started = e.tick
			elif (e.type == FightEvent.STRIKE_LANDED or e.type == FightEvent.STRIKE_MISSED) and chosen.has(started) and not e.data.has("reason"):
				var bonuses: Array = e.data.odds.bonuses.map(func(b: Dictionary) -> String: return b.name)
				assert_has(bonuses, chosen[started], "a counter chosen at tick %d landed outside what it was timed to catch" % started)
				counters += 1
	assert_gt(counters, 12, "the counter-puncher should find plenty of counters")


# --- Tells and set-ups -------------------------------------------------------------

func test_the_kicker_follows_a_blocked_jab_with_a_body_kick_about_70_percent_of_the_time() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	sim.fighters[0].pos = Vector2(-0.95, 0.0)
	sim.fighters[1].pos = Vector2(0.95, 0.0)
	var ai: FighterAI = _ai(sim)
	var followed := 0
	for k in 300:
		ai._follow = {}
		ai.on_event(sim.views[0], FightEvent.new(k, 1, FightEvent.STRIKE_MISSED, 0, { "action_id": "jab", "target": "head", "chance": 0.5 }), sim.decisions[0])
		followed += 1 if ai._follow.get("id", "") == "body_kick" else 0
	assert_almost_eq(followed / 300.0, 0.7, 0.08)
	var d: Decision = ai.choose(sim.views[0], sim.decisions[0])
	assert_eq(d.action_id, "body_kick")
	assert_eq(d.reason, "tell: jab blocked")


func test_a_jab_that_falls_short_is_not_a_blocked_jab() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	var ai: FighterAI = _ai(sim)
	for k in 50:
		ai.on_event(sim.views[0], FightEvent.new(k, 1, FightEvent.STRIKE_MISSED, 0, { "action_id": "jab", "target": "head", "chance": 0.0, "reason": "out of range" }), sim.decisions[0])
	assert_true(ai._follow.is_empty())


func test_the_wrestler_shifts_his_stance_before_he_shoots() -> void:
	var sim := FightSim.new(SEED, [_roster.make("wrestler"), _statue()], _actions)
	for k in 3000:
		sim.tick()
		if not sim.situation.is_standing():
			sim._break_apart(1)  # The statue never gets up on its own: stand them up to see the next shot.
	var starts: Array[Dictionary] = _starts(sim, 0)
	var shots: int = 0
	var after_shift: int = 0
	for n in starts.size():
		if starts[n].action_id != "double_leg" or starts[n].why.begins_with("opening") or starts[n].why.begins_with("counters") \
				or starts[n].why == "shoots off the feint" \
				or starts[n].why == "takes it down from the clinch":  # Set up with a feint (D131), or tied up on the fence first (D234).
			continue
		shots += 1
		if n > 0 and starts[n - 1].action_id == "stance_shift" and starts[n].tick - starts[n - 1].tick <= 10:
			after_shift += 1
			assert_eq(starts[n].why, "tell: stance shift")
	assert_gt(shots, 5, "the wrestler should shoot")
	assert_eq(after_shift, shots, "every shot he leads with comes straight after a stance shift")
	var shifts: int = starts.filter(func(s: Dictionary) -> bool: return s.action_id == "stance_shift").size()
	assert_gt(shifts, shots, "now and then the shift comes with no shot (the 10%)")


# --- The range plan and the feet ---------------------------------------------------

func test_each_fighter_plans_to_fight_where_their_weapons_beat_the_opponents() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	assert_eq(_ai(sim, 0).plan(sim.views[0], sim.decisions[0]), Octagon.BAND_LONG, "kicks reach where punches don't")
	assert_eq(_ai(sim, 1).plan(sim.views[1], sim.decisions[1]), Octagon.BAND_POCKET, "the hook only works in the pocket")


func test_a_pressure_fighter_stalks_into_kicking_range_and_closes_fast_behind_a_kick() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	sim.fighters[0].pos = Vector2(-1.3, 0.0)
	sim.fighters[1].pos = Vector2(1.3, 0.0)
	var gap: float = sim.distance()
	var step: float = sim.step_length(1)
	var stalking: float = sim.preferred_distance(1)
	assert_gt(stalking, gap - step, "against a free kicker at long range he walks in at part pace")
	assert_lt(stalking, gap, "but he still walks in")
	sim.fighters[0].action_id = "body_kick"
	sim.fighters[0].phase = "windup"
	assert_lt(sim.preferred_distance(1), Octagon.POCKET_WITHIN, "a kick on the way: close the distance at full speed")


func test_an_outside_fighter_circles_when_pressed_and_a_pressure_fighter_walks_straight_in() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	sim.preferred_distance(0)
	assert_gt(sim.decisions[0].circling(sim.views[0]), 0.4, "the Kicker circles off a Boxer in his face")
	assert_eq(sim.decisions[1].circling(sim.views[1]), 0.0, "the Boxer walks straight in")


func test_a_fighter_backed_onto_the_fence_circles_out_when_the_opponent_commits() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	# The Kicker 0.3 m off the fence, the Boxer pressing straight in from the middle and throwing.
	sim.fighters[0].pos = Vector2(3.9, 0.0)
	sim.fighters[1].pos = Vector2(2.6, 0.0)
	sim.fighters[1].action_id = "jab"
	sim.fighters[1].phase = "windup"
	var feet: FeetPlan = sim.decisions[0].plan_feet(sim.views[0])
	assert_lt(feet.want, 2.0, "he doesn't try to back up through the fence to kicking range")
	assert_eq(feet.circle, 1.0, "he circles out all he can while the Boxer is busy")
	assert_ne(feet.way, 0, "and picks a way out")
	# The same pressure in open space: he backs out to his range.
	sim.fighters[0].pos = Vector2(0.65, 0.0)
	sim.fighters[1].pos = Vector2(-0.65, 0.0)
	assert_gt(sim.preferred_distance(0), Octagon.MID_WITHIN)


func test_an_outside_fighter_holds_his_ground_where_the_opponent_cant_reach_him() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	# Long range: the Kicker's kicks reach, the Boxer's punches don't. He wants 2.8 m but stands.
	sim.fighters[0].pos = Vector2(-1.25, 0.0)
	sim.fighters[1].pos = Vector2(1.25, 0.0)
	assert_almost_eq(sim.preferred_distance(0), 2.5, 0.001, "he holds at 2.5 m instead of backing up")
	# In the pocket the Boxer's hands work: he gives ground back to his spot.
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	assert_gt(sim.preferred_distance(0), Octagon.MID_WITHIN)


func test_a_pressure_fighter_steps_across_to_cut_off_a_fighter_near_the_fence() -> void:
	# A statue 0.4 m off the fence; the presser off to one side of the line from it to the middle.
	var sim := _sim(FighterState.new("Presser", {}, ["jab"], 0.0, StyleLeanings.new({ "range": 100 })), _statue())
	sim.fighters[0].pos = Vector2(2.6, 1.2)
	sim.fighters[1].pos = Vector2(3.8, 0.0)
	assert_gt(sim.decisions[0].plan_feet(sim.views[0]).cut, 0.9, "a Range +100 fighter cuts all he can")
	for n in 10:
		sim.tick()
	assert_lt(absf(sim.fighters[0].pos.y), 0.6, "he has stepped across toward the line from the statue to the middle")


func test_circling_fighters_change_direction_now_and_then() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	var ways: Array[int] = [0, 0]
	var before: float = (sim.fighters[0].pos - sim.fighters[1].pos).angle()
	for n in 900:
		sim.tick()
		var angle: float = (sim.fighters[0].pos - sim.fighters[1].pos).angle()
		var turned: float = wrapf(angle - before, -PI, PI)
		if absf(turned) > 0.01:
			ways[0 if turned > 0.0 else 1] += 1
		before = angle
	assert_gt(mini(ways[0], ways[1]), 50, "ticks the Kicker went each way round the Boxer: %s" % [ways])


func test_the_time_spent_cutting_off_counts_only_ticks_with_the_cut_working() -> void:
	# The cut-off setup above: the presser cuts while the statue is out by the fence.
	var sim := _sim(FighterState.new("Presser", {}, ["jab"], 0.0, StyleLeanings.new({ "range": 100 })), _statue())
	sim.fighters[0].pos = Vector2(2.6, 1.2)
	sim.fighters[1].pos = Vector2(3.8, 0.0)
	_ticks(sim, 10)
	assert_gt(sim.cutting_ticks[0], 0, "stepping across to cut off counts (D119)")
	assert_eq(sim.circling_ticks[0], 0, "a Range +100 fighter walks straight, he doesn't circle")
	assert_eq(sim.circling_ticks[1], 0, "a Range 0 fighter who isn't hurt doesn't circle either")
	# With the statue in the middle there's no exit to shut, so the cut isn't working.
	var open := _sim(FighterState.new("Presser", {}, ["jab"], 0.0, StyleLeanings.new({ "range": 100 })), _statue())
	open.fighters[0].pos = Vector2(-2.0, 1.0)
	open.fighters[1].pos = Vector2(0.0, 0.0)
	_ticks(open, 10)
	assert_eq(open.cutting_ticks[0], 0, "no cutting off in open space")


func test_the_time_spent_circling_counts_real_circling_not_the_everyday_drift() -> void:
	# Pressed in the pocket the Kicker circles (over 0.4 of a step); at range he only drifts (0.15).
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	_ticks(sim, 1)
	assert_eq(sim.circling_ticks[0], 1, "circling off a Boxer in his face counts")
	assert_eq(sim.circling_ticks[1], 0, "the Boxer walks straight in")
	var drifting := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	drifting.fighters[0].pos = Vector2(-1.25, 0.0)
	drifting.fighters[1].pos = Vector2(1.25, 0.0)
	drifting.preferred_distance(0)
	assert_between(drifting.decisions[0].circling(drifting.views[0]), 0.01, FightSim.CIRCLING_FROM - 0.01, "a drift sideways, not circling")


func test_over_a_fight_the_kicker_circles_and_the_boxer_cuts_off_the_cage() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions, 1, 300)
	sim.run_to_end()
	for i in 2:
		assert_lte(sim.circling_ticks[i] + sim.cutting_ticks[i], sim.now, "never more than the fight's time")
	assert_gt(sim.circling_ticks[0], sim.now / 5, "the Kicker circles a good part of the round: %d of %d ticks" % [sim.circling_ticks[0], sim.now])
	assert_gt(sim.cutting_ticks[1], sim.cutting_ticks[0], "the Boxer does the cutting off")
	assert_gt(sim.circling_ticks[0], sim.circling_ticks[1], "and the Kicker the circling")


func test_an_outside_fighter_caught_in_the_pocket_gets_out_instead_of_trading() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	var ai: FighterAI = _ai(sim)
	sim.fighters[0].pos = Vector2(-1.3, 0.0)
	sim.fighters[1].pos = Vector2(1.3, 0.0)
	ai.plan(sim.views[0], sim.decisions[0])
	var at_range: float = ai.lead_rate(sim.views[0], sim.decisions[0])
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	assert_true(ai.crowded(sim.views[0]))
	assert_lt(ai.lead_rate(sim.views[0], sim.decisions[0]), at_range * 0.5)
	assert_gt(sim.preferred_distance(0), Octagon.MID_WITHIN, "and wants back out to kicking range")


func test_safe_fighters_throw_quick_shots_and_wild_ones_throw_big_ones() -> void:
	var head_kick: int = _actions.total_ticks("head_kick")
	var jab: int = _actions.total_ticks("jab")
	assert_lt(FighterAI.commitment(-100.0, head_kick) / FighterAI.commitment(-100.0, jab),
		FighterAI.commitment(100.0, head_kick) / FighterAI.commitment(100.0, jab))
	assert_eq(FighterAI.commitment(0.0, head_kick, 0.0), 1.0, "where nothing of theirs can punish it, a big shot costs nothing extra")
	assert_lt(FighterAI.commitment(0.0, head_kick, 1.0), FighterAI.commitment(0.0, head_kick, 0.5), "and right in their weapons it costs more")


func test_better_technique_chains_more_combinations() -> void:
	var sim: FightSim = _sim(FighterState.new("Slick", { "boxing": 90 }, ["jab"], 0.02), FighterState.new("Crude", { "boxing": 20 }, ["jab"], 0.02))
	var jab: Dictionary = _actions.get_action("jab")
	var slick: float = _ai(sim, 0).combo_chance(sim.views[0], sim.decisions[0], jab)
	var crude: float = _ai(sim, 1).combo_chance(sim.views[1], sim.decisions[1], jab)
	assert_almost_eq(slick, 0.15 + 0.45 * 0.9, 0.001)
	assert_gt(slick, crude * 2.0)


func test_a_rocked_fighter_covers_up_and_a_hurt_opponent_gets_swarmed() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	var normal: float = _ai(sim, 1).lead_rate(sim.views[1], sim.decisions[1])
	sim.fighters[1].rocked_ticks = 20
	assert_lt(_ai(sim, 1).lead_rate(sim.views[1], sim.decisions[1]), normal * 0.5, "rocked: cover up")
	assert_gt(sim.preferred_distance(1), Octagon.LONG_WITHIN, "and get out of there")
	var calm: float = 0.0
	sim.fighters[1].rocked_ticks = 0
	calm = _ai(sim, 0).lead_rate(sim.views[0], sim.decisions[0])
	sim.fighters[1].rocked_ticks = 20
	assert_gt(_ai(sim, 0).lead_rate(sim.views[0], sim.decisions[0]), calm * 1.4, "the other one smells blood")


func test_moving_costs_stamina() -> void:
	var walker := FighterState.new("Walker", {}, ["jab"], 0.0, StyleLeanings.new({ "range": 100, "pace": 100 }))
	var sim: FightSim = _sim(walker, _statue(), 6.0)
	sim.fighters[0].pos = Vector2(-3.5, 0.0)
	sim.fighters[1].pos = Vector2(3.5, 0.0)
	sim.fighters[0].stamina = 50.0
	sim.fighters[1].stamina = 50.0
	_ticks(sim, 20)
	assert_lt(sim.fighters[0].stamina, sim.fighters[1].stamina, "walking across the cage costs a little breath")
	assert_gt(sim.fighters[0].stamina, 50.0, "but less than breathing gives back")


# --- In character -------------------------------------------------------------------

func test_the_kicker_and_the_boxer_fight_in_character() -> void:
	var thrown := [{}, {}]
	var long_ticks: int = 0
	var pocket_ticks: int = 0
	for n in 2:
		var sim := FightSim.new(SEED + n, _roster.make_pair("kicker", "boxer"), _actions)
		while not sim.is_over():
			sim.tick()
			long_ticks += 1 if sim.band() == Octagon.BAND_LONG else 0
			pocket_ticks += 1 if sim.band() == Octagon.BAND_POCKET else 0
		for i in 2:
			for s in _starts(sim, i):
				thrown[i][s.action_id] = thrown[i].get(s.action_id, 0) + 1
	var kicks: int = 0
	for id in ["teep", "leg_kick", "body_kick", "head_kick"]:
		kicks += thrown[0].get(id, 0)
	# He jabs a fair bit too: holding his ground (D107), he meets the Boxer's walk-ins, and the jab is the quickest stop.
	assert_gt(kicks, thrown[0].get("jab", 0) * 1.5, "the Kicker kicks: %s" % [thrown[0]])
	assert_gt(thrown[1].get("cross", 0) + thrown[1].get("hook", 0), 20, "the Boxer throws his power punches: %s" % [thrown[1]])
	assert_gt(long_ticks, pocket_ticks, "the Kicker mostly keeps it at his range (long %d, pocket %d ticks)" % [long_ticks, pocket_ticks])
	assert_gt(pocket_ticks, 1000, "but the Boxer gets inside now and then")
