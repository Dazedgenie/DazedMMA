extends GutTest
## Submissions (docs/01 §25, D126): the guillotine, triangle and armbar lock in like any grapple,
## then the struggle: a danger meter that goes up or down each beat until a tap or an escape.
## The struggle calls, the judges, the referee's count and the AI's tries.

const SEED: int = 20261027
## Enough seeds that a 95% move works on most of them and a rarer outcome turns up.
const SEEDS: int = 40
## Stats that win (or lose) every contest the hold has.
const BEST := { "submissions": 100, "guard": 100, "strength": 100 }
const WORST := { "submission_defense": 0, "top_control": 0, "strength": 0, "scrambles": 0 }

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, a step apart in the middle of the cage.
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	return sim


## Blue takes Red down (no roll): full guard, Red on the bottom.
func _red_underneath(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	var sim: FightSim = _pair(red_stats, blue_stats, fight_seed)
	assert_true(sim.apply_transition(1, "double_leg"))
	return sim


## Red's hold locks in on the spot (no roll), from Red underneath in full guard.
func _locked(id: String, red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	var sim: FightSim = _red_underneath(red_stats, blue_stats, fight_seed)
	assert_true(sim._lock_in(0, _actions.get_action(id)))
	return sim


## Blue's shot was sprawled on: stuck in its recovery with the head low.
func _blue_stuck_under_a_sprawl(sim: FightSim) -> void:
	var b: FighterState = sim.fighters[1]
	b.action_id = "double_leg"
	b.phase = "recovery"
	b.phase_ticks_left = 9
	b.sprawled = true


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


# --- Locking in -----------------------------------------------------------------------

func test_every_submission_has_somewhere_to_lock_into_from_every_position_it_is_done_from() -> void:
	var positions := PositionLibrary.shared()
	for id: String in ["guillotine", "triangle", "armbar", "rear_naked_choke", "arm_triangle", "ankle_lock", "kneebar", "heel_hook"]:
		var action: Dictionary = _actions.get_action(id)
		assert_eq(action.category, "submission")
		for from: String in action.positions:
			var role: String = ""
			for r: String in positions.get_position(from).roles:
				if ActionLibrary.allows_role(action, r) and positions.leads_somewhere(from, r, action):
					role = r  # The armbar: the bottom of full guard, the top of mount (D130).
			var t: Dictionary = positions.transition(from, role, id)
			assert_eq(t.get("to", ""), PositionLibrary.SUBMISSION, "%s from %s" % [id, from])
			assert_eq(t.roles.actor, PositionLibrary.ATTACKER)
			assert_eq(t.roles.opponent, PositionLibrary.DEFENDER)


func test_a_triangle_that_locks_moves_the_fight_to_the_submission_position_and_starts_the_struggle() -> void:
	var locked: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_underneath({ "submissions": 100, "guard": 100 }, { "submission_defense": 80, "top_control": 80 }, SEED + n)
		_queue(sim, sim.now, 0, "triangle")
		_ticks(sim, 8)  # Wind-up 0.3 s, active 0.4 s: rolled as the active phase ends.
		var won: Array[FightEvent] = _events(sim, FightEvent.SUBMISSION_LOCKED, 0)
		if won.is_empty():
			continue
		locked += 1
		assert_eq(sim.situation.position, PositionLibrary.SUBMISSION)
		assert_eq(sim.situation.roles, [PositionLibrary.ATTACKER, PositionLibrary.DEFENDER] as Array[String])
		assert_eq(won[0].data.danger, 50, "start_danger 40 + 0.5 × (100 − 80)")
		assert_eq(sim.hold().action_id, "triangle")
	assert_between(locked, 10, 30, "45% to lock (base 25% + 20 points of stats)")


func test_locking_in_scores_with_the_judges() -> void:
	var sim: FightSim = _red_underneath()
	var before: float = sim.round_points()[0]
	assert_true(sim._lock_in(0, _actions.get_action("triangle")))
	assert_almost_eq(sim.round_points()[0], before + Judging.SUB_LOCK_POINTS, 0.0001)
	assert_eq(sim.fighters[0].subs_locked, 1)


func test_nobody_starts_a_move_while_a_hold_is_on() -> void:
	var sim: FightSim = _locked("triangle")
	assert_eq(sim.why_not(1, "ground_punch"), "not possible from this position")
	assert_eq(sim.why_not(0, "get_up"), "not possible from this position")
	_queue(sim, sim.now, 1, "ground_punch")
	_ticks(sim, 3)
	assert_eq(sim.fighters[1].action_id, "", "the queued punch never starts")


func test_a_guillotine_needs_the_head_low() -> void:
	var sim: FightSim = _pair(BEST, WORST)
	_queue(sim, 0, 0, "guillotine")
	_ticks(sim, 3)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 0)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0].data.reason, "nothing to catch")
	assert_eq(sim.situation.position, PositionLibrary.STANDING, "and it costs nothing more than the move")


func test_a_guillotine_on_a_sprawled_shot_can_lock() -> void:
	var locked: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair(BEST, WORST, SEED + n)
		_blue_stuck_under_a_sprawl(sim)
		_queue(sim, 0, 0, "guillotine")
		_ticks(sim, 5)
		if not _events(sim, FightEvent.SUBMISSION_LOCKED, 0).is_empty():
			locked += 1
	assert_gt(locked, SEEDS * 3 / 4)


func test_a_guillotine_that_misses_pulls_the_attacker_onto_their_back() -> void:
	var pulled: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "submissions": 0, "strength": 0 }, { "submission_defense": 100, "scrambles": 100 }, SEED + n)
		_blue_stuck_under_a_sprawl(sim)
		_queue(sim, 0, 0, "guillotine")
		_ticks(sim, 5)
		if _events(sim, FightEvent.GRAPPLE_STOPPED, 0).is_empty():
			continue
		pulled += 1
		assert_eq(sim.situation.position, "full_guard")
		assert_eq(sim.situation.roles, [PositionLibrary.BOTTOM, PositionLibrary.TOP] as Array[String])
		assert_gte(sim.round_points()[1], Judging.TAKEDOWN_POINTS, "Blue ends up on top, and the judges see it")
	assert_gt(pulled, SEEDS * 3 / 4)


# --- The struggle -------------------------------------------------------------------------

func test_a_much_better_attacker_makes_the_defender_tap() -> void:
	var tapped: int = 0
	for n in SEEDS:
		var sim: FightSim = _locked("triangle", BEST, WORST, SEED + n)
		_ticks(sim, FightSim.STRUGGLE_BEAT_TICKS * FightSim.STRUGGLE_BEATS + 1)
		var ended: Array[FightEvent] = _events(sim, FightEvent.FIGHT_ENDED)
		if ended.is_empty():
			continue
		tapped += 1
		assert_eq(ended[0].data.result, FightSim.RESULT_SUB)
		assert_eq(ended[0].data.winner, 0)
		assert_eq(ended[0].data.why, "triangle", "the hold that did it")
	assert_gt(tapped, SEEDS * 3 / 4)


func test_each_beat_moves_the_danger_one_step_and_costs_both_fighters() -> void:
	var sim: FightSim = _locked("triangle")
	var start: float = float(sim.hold().danger)
	var stamina: Array[float] = [sim.fighters[0].stamina, sim.fighters[1].stamina]
	_ticks(sim, FightSim.STRUGGLE_BEAT_TICKS + 1)
	var beats: Array[FightEvent] = _events(sim, FightEvent.SUBMISSION_BEAT, 0)
	assert_eq(beats.size(), 1, "one beat a second")
	var moved: float = FightSim.STRUGGLE_STEP if beats[0].data.gained else -FightSim.STRUGGLE_STEP
	if not sim.hold().is_empty():
		assert_almost_eq(float(sim.hold().danger), start + moved, 0.0001)
	for k in 2:
		assert_lt(sim.fighters[k].stamina, stamina[k] - FightSim.STRUGGLE_STAMINA + 0.0001)


func test_a_much_better_defender_escapes_a_triangle_back_to_full_guard() -> void:
	var sim: FightSim = _locked("triangle", { "submissions": 0, "guard": 0 }, { "submission_defense": 100, "top_control": 100 })
	assert_eq(sim.hold().danger, FightSim.START_DANGER_MIN, "start_danger 40 − 50, kept at 10")
	_ticks(sim, FightSim.STRUGGLE_BEAT_TICKS * FightSim.STRUGGLE_BEATS + 1)
	assert_false(_events(sim, FightEvent.SUBMISSION_ESCAPED, 1).is_empty())
	assert_true(sim.hold().is_empty())
	assert_eq(sim.situation.position, "full_guard")
	assert_eq(sim.situation.roles, [PositionLibrary.BOTTOM, PositionLibrary.TOP] as Array[String], "back where it was locked from")


func test_getting_out_of_an_armbar_ends_in_a_scramble() -> void:
	var sim: FightSim = _locked("armbar", { "submissions": 0, "guard": 0 }, { "submission_defense": 100, "strength": 100 })
	_ticks(sim, FightSim.STRUGGLE_BEAT_TICKS * FightSim.STRUGGLE_BEATS + 1)
	assert_eq(sim.situation.position, PositionLibrary.SCRAMBLE)
	var moved: Array[FightEvent] = _events(sim, FightEvent.POSITION_CHANGED, 1)
	assert_true(moved[-1].data.get("escaped", false))


func test_surviving_every_beat_is_an_escape_too() -> void:
	var sim: FightSim = _locked("triangle")
	var hold: Dictionary = sim.hold()  # The sim's own hold, not a copy.
	hold.danger = 50.0
	hold.beats = FightSim.STRUGGLE_BEATS - 1
	_ticks(sim, FightSim.STRUGGLE_BEAT_TICKS + 1)
	assert_eq(_events(sim, FightEvent.SUBMISSION_ESCAPED).size(), 1, "the last beat gone and still no tap (50 ± 20)")
	assert_true(sim.hold().is_empty())


func test_a_hold_that_nearly_finishes_counts_as_impact_for_the_judges() -> void:
	var sim: FightSim = _locked("triangle", BEST, WORST)
	var hold: Dictionary = sim.hold()
	hold.danger = FightSim.NEAR_FINISH - FightSim.STRUGGLE_STEP + 1.0
	for n in 30:
		if sim.is_over() or int(sim.round_impact()[0]) > 0:
			break
		sim.tick()
	assert_eq(sim.round_impact()[0], 1)


func test_the_bell_saves_a_fighter_in_a_hold() -> void:
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, [], 0.0), FighterState.new("Blue", {}, [], 0.0)], _actions, 2, 1)
	sim.apply_transition(1, "double_leg")
	assert_true(sim._lock_in(0, _actions.get_action("triangle")))
	_ticks(sim, FightClock.TICKS_PER_SECOND + 1)
	if not sim.is_over():
		assert_true(sim.hold().is_empty())
		assert_eq(sim.situation.position, PositionLibrary.STANDING)


# --- The calls --------------------------------------------------------------------------------

func test_finish_it_and_defend_the_sub_push_the_struggle_each_way() -> void:
	var sim: FightSim = _locked("triangle")
	var plain: float = sim.struggle_share()
	sim.decisions[0].calls.focus = { "call": sim.calls.get_call("finish_it"), "until": sim.now + 50 }
	assert_almost_eq(sim.struggle_share(), plain + 0.15, 0.0001)
	sim.decisions[1].calls.focus = { "call": sim.calls.get_call("defend_the_sub"), "until": sim.now + 50 }
	assert_almost_eq(sim.struggle_share(), plain, 0.0001, "the two cancel out")
	assert_eq(sim.decisions[0].calls.struggle_stamina(), 2.0, "and each costs its fighter more stamina a beat")


func test_the_struggle_calls_only_work_in_a_hold_and_from_their_side() -> void:
	var sim: FightSim = _locked("triangle")
	var finish: Dictionary = sim.calls.get_call("finish_it")
	var defend: Dictionary = sim.calls.get_call("defend_the_sub")
	assert_eq(FightHud.call_problem(sim, 0, finish), "")
	assert_eq(FightHud.call_problem(sim, 1, finish), "not from the defender")
	assert_eq(FightHud.call_problem(sim, 1, defend), "")
	var standing: FightSim = _pair()
	assert_eq(FightHud.call_problem(standing, 0, finish), "not from here")


func test_the_corner_calls_finish_it_or_defend_the_sub_when_a_hold_locks() -> void:
	var sim: FightSim = _red_underneath()
	sim.corners[0] = Corner.new(Corner.IDEAL, 1)
	sim.corners[1] = Corner.new(Corner.IDEAL, 2)
	assert_true(sim._lock_in(0, _actions.get_action("triangle")))
	_ticks(sim, Corner.IDEAL_REACTION + 2)
	var calls: Array[String] = []
	for e in _events(sim, FightEvent.CALL_HEARD):
		calls.append("%d:%s" % [e.actor, e.data.call_id])
	assert_has(calls, "0:finish_it")
	assert_has(calls, "1:defend_the_sub")


# --- The AI -----------------------------------------------------------------------------------

func test_underneath_the_ai_goes_for_a_triangle_when_the_top_fighters_posture_is_broken() -> void:
	var red := FighterState.new("Red", { "submissions": 100 }, ["triangle"], 0.015)
	var blue := FighterState.new("Blue", { "submission_defense": 100, "top_control": 100 }, [], 0.0)
	var sim := FightSim.new(SEED, [red, blue], _actions, 1, 300)
	sim.apply_transition(1, "double_leg")
	var starts: Array[int] = []
	for n in 1500:
		if sim.is_over():
			break
		if sim.situation.position == "full_guard":
			sim.fighters[1].tied_up_ticks = 100  # Posture broken the whole time.
		sim.tick()
	for e in _events(sim, FightEvent.ACTION_PHASE, 0):
		if e.data.action_id == "triangle" and e.data.phase == "telegraph":
			starts.append(e.tick)
	assert_gt(starts.size(), 0, "goes for it on the opening")
	for k in range(1, starts.size()):
		assert_gte(starts[k] - starts[k - 1], FighterAI.SUB_RETRY_TICKS, "and waits before the next try")


func test_underneath_the_ai_never_goes_for_a_hold_without_its_opening() -> void:
	var red := FighterState.new("Red", { "submissions": 100 }, ["armbar"], 0.015)
	var blue := FighterState.new("Blue", {}, [], 0.0)  # Never throws, so never postures up.
	var sim := FightSim.new(SEED, [red, blue], _actions, 1, 300)
	sim.apply_transition(1, "double_leg")
	_ticks(sim, 1500)
	for e in _events(sim, FightEvent.ACTION_PHASE, 0):
		assert_ne(e.data.action_id, "armbar")


func test_a_sprawler_sometimes_goes_for_the_guillotine_on_the_stuck_head() -> void:
	var tried: int = 0
	for n in SEEDS:
		var red := FighterState.new("Red", {}, ["jab"], 0.015)
		var sim := FightSim.new(SEED + n, [red, FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
		sim.fighters[0].pos = Vector2(-0.5, 0.0)
		sim.fighters[1].pos = Vector2(0.5, 0.0)
		_blue_stuck_under_a_sprawl(sim)
		_ticks(sim, 3)
		for e in _events(sim, FightEvent.ACTION_PHASE, 0):
			if e.data.action_id == "guillotine":
				tried += 1
				break
	assert_gt(tried, 0)
	assert_lt(tried, SEEDS, "one look per stuck shot, not every time")
