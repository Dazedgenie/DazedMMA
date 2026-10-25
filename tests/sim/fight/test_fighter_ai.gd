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
	_ticks(sim, 3000)
	var starts: Array[Dictionary] = _starts(sim, 0)
	var shots: int = 0
	var after_shift: int = 0
	for n in starts.size():
		if starts[n].action_id != "double_leg" or starts[n].why.begins_with("opening") or starts[n].why.begins_with("counters"):
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


func test_a_fighter_backing_onto_the_fence_circles_off_it_instead() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
	# The Kicker 0.3 m off the fence, the Boxer pressing straight in from the middle.
	sim.fighters[0].pos = Vector2(3.9, 0.0)
	sim.fighters[1].pos = Vector2(2.6, 0.0)
	assert_lt(sim.preferred_distance(0), 2.0, "he doesn't try to back up through the fence to kicking range")
	assert_gt(_ai(sim, 0).circling(sim.views[0], sim.decisions[0]), 0.7, "he circles off it")
	# The same pressure in open space: he backs straight out to his range.
	sim.fighters[0].pos = Vector2(0.65, 0.0)
	sim.fighters[1].pos = Vector2(-0.65, 0.0)
	assert_gt(sim.preferred_distance(0), Octagon.MID_WITHIN)


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
	assert_gt(kicks, thrown[0].get("jab", 0) * 2, "the Kicker kicks: %s" % [thrown[0]])
	assert_gt(thrown[1].get("cross", 0) + thrown[1].get("hook", 0), 20, "the Boxer throws his power punches: %s" % [thrown[1]])
	assert_gt(long_ticks, pocket_ticks, "the Kicker mostly keeps it at his range (long %d, pocket %d ticks)" % [long_ticks, pocket_ticks])
	assert_gt(pocket_ticks, 1000, "but the Boxer gets inside now and then")
