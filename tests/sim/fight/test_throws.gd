extends GutTest
## Throws and the guard game (docs/01 §26, D127): the outside trip and hip throw from the clinch,
## the foot sweep on a lean, the guard pull and the sweep from the bottom, what a sprawl can't do
## to a throw, the judges, the AI and the Judoka and BJJ fighters.

const SEED: int = 20261028
## Enough seeds that a likely move works on most of them and a rarer outcome turns up.
const SEEDS: int = 40
## Stats that win (or lose) every contest a throw has.
const BEST := { "takedowns": 100, "clinch_control": 100, "strength": 100, "speed": 100, "guard": 100, "scrambles": 100 }
const WORST := { "takedown_defense": 0, "clinch_control": 0, "footwork": 0, "top_control": 0, "strength": 0 }

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` apart in the middle of the cage.
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED, gap: float = 1.2, rules: Variant = 1) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, rules, 300)
	sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	return sim


## The same two tied up in the clinch (no roll).
func _clinched(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim: FightSim = _pair(red_stats, blue_stats, fight_seed, 1.2, rules)
	assert_true(sim.apply_transition(0, "clinch_entry"))
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)))


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		if sim.is_over():
			return
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


func _starts(sim: FightSim, fighter: int) -> Array[String]:
	var out: Array[String] = []
	for e in _events(sim, FightEvent.ACTION_PHASE, fighter):
		if e.data.phase == "telegraph":
			out.append(e.data.action_id)
	return out


func _bonus_names(odds: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for b: Dictionary in odds.get("bonuses", []):
		out.append(b.name)
	return out


# --- The throws ----------------------------------------------------------------------------

func test_every_throw_is_a_takedown_that_lands_on_top_in_full_guard() -> void:
	var positions := PositionLibrary.shared()
	for id: String in ["outside_trip", "hip_throw", "foot_sweep"]:
		var action: Dictionary = _actions.get_action(id)
		assert_true(ActionLibrary.is_throw(action), id)
		for from: String in action.positions:
			var t: Dictionary = positions.transition(from, PositionLibrary.NEUTRAL, id)
			assert_eq(t.get("to", ""), "full_guard", "%s from %s" % [id, from])
			assert_eq(t.roles.actor, PositionLibrary.TOP)
	assert_false(ActionLibrary.is_throw(_actions.get_action("double_leg")), "a shot is not a throw")


func test_an_outside_trip_from_the_clinch_puts_him_down_and_counts_as_a_takedown() -> void:
	var landed: int = 0
	for n in SEEDS:
		var sim: FightSim = _clinched(BEST, WORST, SEED + n)
		_queue(sim, sim.now, 0, "outside_trip")
		_ticks(sim, 8)  # Telegraph 0.1 s, wind-up 0.2 s, active 0.3 s: rolled as the active phase ends.
		if _events(sim, FightEvent.GRAPPLE_WON, 0).is_empty():
			continue
		landed += 1
		assert_eq(sim.situation.position, "full_guard")
		assert_eq(sim.situation.roles, [PositionLibrary.TOP, PositionLibrary.BOTTOM] as Array[String])
		assert_eq(sim.fighters[0].takedowns_tried, 1)
		assert_eq(sim.fighters[0].throws_tried, 1)
		assert_eq(sim.fighters[0].takedowns_landed, 1, "a throw is a takedown")
		assert_eq(sim.fighters[0].throws_landed, 1)
		assert_gte(sim.round_points()[0], Judging.TAKEDOWN_POINTS)
	assert_gt(landed, SEEDS * 3 / 4)


func test_a_sprawl_does_nothing_to_a_throw() -> void:
	for n in 10:
		var sim: FightSim = _clinched({}, { "takedown_defense": 100, "speed": 100 }, SEED + n)
		_queue(sim, sim.now, 0, "outside_trip")
		_queue(sim, sim.now + 2, 1, "sprawl")  # Sprawling as the trip makes contact.
		_ticks(sim, 8)
		assert_eq(_events(sim, FightEvent.SPRAWLED).size(), 0, "nothing to sprawl on")
		assert_eq(_events(sim, FightEvent.GRAPPLE_WON, 0).size() + _events(sim, FightEvent.GRAPPLE_STOPPED, 0).size(), 1, "the trip rolls on its own")


func test_a_trip_likes_the_fence_and_a_hip_throw_needs_room() -> void:
	var sim: FightSim = _pair()
	sim.fighters[1].pos = Vector2(4.1, 0.0)  # Blue's back on the fence.
	sim.fighters[0].pos = Vector2(2.9, 0.0)
	assert_true(sim.apply_transition(0, "clinch_entry"))
	assert_has(sim.active_flags(1), "BACK_TO_CAGE")
	var trip: OddsBreakdown = sim.odds_breakdown(0, "outside_trip")
	assert_has(_bonus_names(trip.to_dict()), "BACK_TO_CAGE")
	assert_almost_eq(trip.chance, 0.4 + 0.15, 0.0001)
	var hip: OddsBreakdown = sim.odds_breakdown(0, "hip_throw")
	assert_almost_eq(hip.chance, 0.35 - 0.10, 0.0001, "no room to turn him over")


func test_a_hip_throw_slams_him_down_where_slams_are_allowed() -> void:
	var slammed: int = 0
	for n in SEEDS:
		var sim: FightSim = _clinched(BEST, WORST, SEED + n)
		_queue(sim, sim.now, 0, "hip_throw")
		_ticks(sim, 10)
		var won: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 0)
		if won.is_empty():
			continue
		slammed += 1
		var expected: int = roundi(8.0 * (0.5 + 100.0 / 100.0))
		assert_eq(won[0].data.landing_damage, expected, "8 × (0.5 + Strength / 100)")
		assert_eq(sim.fighters[1].damage.body, expected)
		var scored: float = Judging.TAKEDOWN_POINTS + expected * Judging.TARGET_WEIGHTS.body
		assert_between(sim.round_points()[0], scored, scored + 0.1, "a takedown and a body shot (plus a moment's control on top)")
	assert_gt(slammed, SEEDS / 2)
	var amateur := Ruleset.load_id("amateur_adult")
	var sim: FightSim = _clinched(BEST, WORST, SEED, amateur)
	assert_eq(sim.landing_damage(0, "hip_throw"), 0, "no slams under amateur rules (docs/08)")
	assert_eq(sim.landing_damage(0, "outside_trip"), 0, "a trip never slams")


func test_a_hip_throw_that_fails_leaves_the_thrower_leaning() -> void:
	var failed: int = 0
	for n in SEEDS:
		var sim: FightSim = _clinched(WORST, { "takedown_defense": 100, "clinch_control": 100 }, SEED + n)
		_queue(sim, sim.now, 0, "hip_throw")
		for k in 12:
			sim.tick()
			if not _events(sim, FightEvent.GRAPPLE_STOPPED, 0).is_empty() or not _events(sim, FightEvent.GRAPPLE_WON, 0).is_empty():
				break
		if _events(sim, FightEvent.GRAPPLE_STOPPED, 0).is_empty():
			continue
		failed += 1
		assert_eq(sim.situation.position, PositionLibrary.CLINCH, "still tied up")
		assert_eq(sim.fighters[0].phase, "recovery")
		assert_has(sim.active_flags(0), "LEANING", "turned the wrong way: a trip or a shot gets in easier")
		assert_has(_bonus_names(sim.odds_breakdown(1, "outside_trip").to_dict()), "LEANING")
	assert_gt(failed, SEEDS * 3 / 4)


func test_a_foot_sweep_needs_him_leaning() -> void:
	var sim: FightSim = _pair(BEST, WORST)
	_queue(sim, 0, 0, "foot_sweep")
	_ticks(sim, 4)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 0)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0].data.reason, "nothing to catch")
	assert_true(sim.situation.is_standing())


func test_a_foot_sweep_timed_on_a_hook_takes_him_down() -> void:
	var swept: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair(BEST, WORST, SEED + n)
		_queue(sim, 0, 1, "hook")  # Leaning from its wind-up (tick 2) to the end of its recovery.
		_queue(sim, 2, 0, "foot_sweep")  # Contact at tick 3.
		_ticks(sim, 6)
		var won: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 0)
		assert_eq(_events(sim, FightEvent.GRAPPLE_STOPPED, 0).filter(func(e: FightEvent) -> bool: return e.data.reason == "nothing to catch").size(), 0)
		if not won.is_empty() and won[0].data.result == PositionLibrary.SUCCESS:
			swept += 1
			assert_has(_bonus_names(won[0].data.odds), "LEANING")
			assert_eq(sim.situation.roles, [PositionLibrary.TOP, PositionLibrary.BOTTOM] as Array[String])
	assert_gt(swept, SEEDS * 3 / 4)


# --- The guard game -------------------------------------------------------------------------

func test_pulling_guard_puts_the_puller_on_the_bottom_and_scores_nothing() -> void:
	var pulled: int = 0
	for n in SEEDS:
		var sim: FightSim = _clinched(BEST, WORST, SEED + n)
		_queue(sim, sim.now, 0, "guard_pull")
		_ticks(sim, 5)
		if _events(sim, FightEvent.GRAPPLE_WON, 0).is_empty():
			continue
		pulled += 1
		assert_eq(sim.situation.position, "full_guard")
		assert_eq(sim.situation.roles, [PositionLibrary.BOTTOM, PositionLibrary.TOP] as Array[String])
		assert_lt(sim.round_points()[1], 0.1, "landing on top of a guard pull isn't a takedown (just a moment's control)")
		assert_eq(sim.fighters[1].takedowns_landed, 0)
	assert_gt(pulled, SEEDS * 3 / 4)


func test_a_sweep_from_the_bottom_puts_the_sweeper_on_top() -> void:
	var swept: int = 0
	var scrambles: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "guard": 75, "scrambles": 75 }, { "top_control": 50 }, SEED + n)
		assert_true(sim.apply_transition(1, "double_leg"))
		var before: float = sim.round_points()[0]
		_queue(sim, sim.now, 0, "sweep")
		_ticks(sim, 8)
		var won: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 0)
		if won.is_empty():
			assert_eq(sim.situation.roles, [PositionLibrary.BOTTOM, PositionLibrary.TOP] as Array[String], "a failed sweep leaves him underneath")
			continue
		if won[0].data.result == PositionLibrary.PARTIAL:
			scrambles += 1
			assert_eq(sim.situation.position, PositionLibrary.SCRAMBLE)
			continue
		swept += 1
		assert_eq(sim.situation.position, "full_guard")
		assert_eq(sim.situation.roles, [PositionLibrary.TOP, PositionLibrary.BOTTOM] as Array[String])
		assert_between(sim.round_points()[0], before + Judging.TAKEDOWN_POINTS, before + Judging.TAKEDOWN_POINTS + 0.1, "judges score a sweep like a takedown")
	assert_between(swept, 10, 30, "50%: base 25% + 25 points of stats")
	assert_gt(scrambles, 0, "some only half work")


# --- The fighter AI ----------------------------------------------------------------------------

func test_a_fighter_who_reads_a_throw_does_not_sprawl_on_it() -> void:
	var reader := FighterState.new("Reader", { "fight_iq": 100, "takedown_defense": 100 }, ["jab"], 0.015)
	var sim := FightSim.new(SEED, [FighterState.new("Thrower", {}, [], 0.0), reader], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	for k in 20:
		_queue(sim, 30 * k, 0, "outside_trip")
	for k in 600:
		if not sim.situation.is_standing() and sim.situation.position != PositionLibrary.CLINCH:
			sim._break_apart(1)
		if sim.situation.is_standing():
			sim.apply_transition(0, "clinch_entry")
		sim.tick()
	assert_does_not_have(_starts(sim, 1), "sprawl", "nothing to sprawl on")


func test_the_ai_takes_a_foot_sweep_on_a_hook_it_reads() -> void:
	var swept: int = 0
	for n in 10:
		var judoka := FighterState.new("Judoka", { "fight_iq": 100, "takedowns": 80 }, ["foot_sweep"], 0.015)
		var sim := FightSim.new(SEED + n, [judoka, FighterState.new("Hooker", {}, [], 0.0)], _actions, 1, 300)
		for k in 15:
			_queue(sim, 20 * k, 1, "hook")
		for k in 300:
			if not sim.situation.is_standing():
				sim._break_apart(1)
			sim.fighters[0].pos = Vector2(-0.6, 0.0)  # Held in the pocket, where both moves reach.
			sim.fighters[1].pos = Vector2(0.6, 0.0)
			sim.tick()
		if _starts(sim, 0).has("foot_sweep"):
			swept += 1
	assert_gt(swept, 5, "a sweep on a lean it reads is taken (D127), unlike the catch (D103)")


func test_the_judoka_throws_in_the_clinch_and_the_bjj_fighter_pulls_guard() -> void:
	var roster := FighterLibrary.load_dir()
	var moves := { "judoka": {}, "bjj": {} }
	for id: String in moves:
		for n in 10:
			var sim := FightSim.new(SEED + n, [roster.make(id), FighterState.new("Statue", {}, [], 0.0)], _actions, 1, 300)
			sim.apply_transition(0, "clinch_entry")
			_ticks(sim, 300)
			var starts: Array[String] = _starts(sim, 0)
			if not starts.is_empty():
				moves[id][starts[0]] = moves[id].get(starts[0], 0) + 1
	var throws: int = moves.judoka.get("outside_trip", 0) + moves.judoka.get("hip_throw", 0)
	assert_gt(throws, moves.judoka.get("clinch_break", 0), "the Judoka throws: %s" % [moves.judoka])
	assert_gt(moves.bjj.get("guard_pull", 0), 0, "the BJJ fighter pulls guard: %s" % [moves.bjj])


func test_underneath_the_bjj_fighter_sweeps_more_than_he_gets_up() -> void:
	var roster := FighterLibrary.load_dir()
	var counts := { "sweep": 0, "get_up": 0 }
	for n in 10:
		var sim := FightSim.new(SEED + n, [roster.make("bjj"), FighterState.new("Statue", {}, [], 0.0)], _actions, 1, 300)
		sim.apply_transition(1, "double_leg")
		_ticks(sim, 300)
		for id in _starts(sim, 0):
			if counts.has(id):
				counts[id] += 1
	assert_gt(counts.sweep, counts.get_up, "%s" % [counts])


# --- Calls and the fighters ------------------------------------------------------------------

func test_the_takedown_call_throws_in_the_clinch_for_a_fighter_who_knows_a_throw() -> void:
	var red := FighterState.new("Red", {}, ["outside_trip"], 0.0)
	red.profile = { "personality": { "ego": -100 } }  # Humble: never ignores a call.
	var sim := FightSim.new(SEED, [red, FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	sim.apply_transition(0, "clinch_entry")
	assert_true(sim.submit(FightCommand.live_call(sim.now, 0, "takedown")))
	_ticks(sim, 30)
	assert_has(_starts(sim, 0), "outside_trip")


func test_real_fights_with_the_judoka_and_the_bjj_fighter_have_throws_and_guard_work() -> void:
	var roster := FighterLibrary.load_dir()
	var judoka := FightSim.new(SEED, roster.make_pair("judoka", "boxer"), _actions)
	judoka.run_to_end()
	assert_gt(judoka.fighters[0].throws_tried, 0, "the Judoka goes for throws")
	var bjj := FightSim.new(SEED, roster.make_pair("bjj", "wrestler"), _actions)
	bjj.run_to_end()
	var starts: Array[String] = _starts(bjj, 0)
	assert_true(starts.has("guard_pull") or starts.has("sweep") or starts.has("triangle") or starts.has("armbar"),
		"the BJJ fighter works his guard: %s" % [starts])
