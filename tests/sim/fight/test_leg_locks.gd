extends GutTest
## Leg locks (docs/01 §30, D132): the ankle lock, kneebar and heel hook, where each is done from,
## what a miss costs, the heel hook's quicker struggle and the amateur ban, the fighter AI going for
## them, and the Sambo fighter.

const SEED: int = 20261029
## Enough seeds that a 95% move works on most of them and a rarer outcome turns up.
const SEEDS: int = 40
const BEST := { "submissions": 100, "scrambles": 100, "strength": 100 }
const WORST := { "submission_defense": 0, "scrambles": 0, "strength": 0 }
const LEG_LOCKS: Array[String] = ["ankle_lock", "kneebar", "heel_hook"]

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _fighter(fighter_name: String, p_stats: Dictionary = {}, moves: Array[String] = [], work_rate: float = 0.0) -> FighterState:
	return FighterState.new(fighter_name, p_stats, moves, work_rate)


## Red on top of Blue in full guard or half guard (no rolls), a step apart in the middle.
func _red_on_top(where: String, red: FighterState, blue: FighterState, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim := FightSim.new(fight_seed, [red, blue], _actions, rules, 300)
	sim.fighters[0].pos = Vector2(-0.6, 0.0)
	sim.fighters[1].pos = Vector2(0.6, 0.0)
	assert_true(sim.apply_transition(0, "double_leg"))
	if where == "half_guard":
		assert_true(sim.apply_transition(0, "guard_pass", PositionLibrary.PARTIAL))
	elif where == PositionLibrary.SCRAMBLE:
		assert_true(sim.apply_transition(1, "sweep", PositionLibrary.PARTIAL))
	assert_eq(sim.situation.position, where)
	return sim


func _queue(sim: FightSim, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(sim.now, fighter, action_id)), action_id)


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


func _starts(sim: FightSim, actor: int) -> Array[String]:
	var out: Array[String] = []
	for e in _events(sim, FightEvent.ACTION_PHASE, actor):
		if e.data.phase == "telegraph":
			out.append(e.data.action_id)
	return out


# --- The holds ------------------------------------------------------------------------

func test_the_three_leg_locks_are_holds_that_go_to_a_scramble_when_he_gets_out() -> void:
	for id: String in LEG_LOCKS:
		var action: Dictionary = _actions.get_action(id)
		assert_true(ActionLibrary.is_leg_lock(action), id)
		assert_eq(String(action.submission.escape_to), PositionLibrary.SCRAMBLE, id)
		assert_true(action.positions.has(PositionLibrary.SCRAMBLE), "%s from a scramble, where legs are everywhere" % id)
	assert_false(ActionLibrary.is_leg_lock(_actions.get_action("armbar")))


func test_the_ankle_lock_and_heel_hook_are_done_from_underneath_and_the_kneebar_from_on_top() -> void:
	var guard: FightSim = _red_on_top("full_guard", _fighter("Red", {}, LEG_LOCKS), _fighter("Blue", {}, LEG_LOCKS))
	assert_eq(guard.why_not(1, "ankle_lock"), "", "from the bottom of full guard")
	assert_eq(guard.why_not(1, "heel_hook"), "")
	assert_ne(guard.why_not(0, "ankle_lock"), "", "not from the top of full guard")
	assert_ne(guard.why_not(0, "kneebar"), "", "no kneebar from inside the full guard")
	var half: FightSim = _red_on_top("half_guard", _fighter("Red", {}, LEG_LOCKS), _fighter("Blue", {}, LEG_LOCKS))
	assert_eq(half.why_not(0, "kneebar"), "", "from the top of half guard: his leg is right there")
	assert_eq(half.why_not(1, "ankle_lock"), "", "and the ankle lock from under it")
	assert_ne(half.why_not(1, "kneebar"), "")


func test_an_ankle_lock_from_underneath_locks_with_every_stat_for_it() -> void:
	var locked: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("full_guard", _fighter("Red", WORST), _fighter("Blue", BEST, ["ankle_lock"]), SEED + n)
		_queue(sim, 1, "ankle_lock")
		_ticks(sim, 7)  # Wind-up 0.2 s, active 0.3 s.
		if sim.situation.position == PositionLibrary.SUBMISSION:
			locked += 1
			assert_eq(String(sim.hold().from), "full_guard")
			assert_eq(sim.fighters[1].leg_locks_locked, 1)
	assert_gt(locked, SEEDS * 3 / 4)


func test_an_ankle_lock_that_misses_lets_him_past_the_legs_and_scores_it() -> void:
	var sim: FightSim = _red_on_top("full_guard", _fighter("Red"), _fighter("Blue", {}, ["ankle_lock"]))
	var before: Array[float] = sim.round_points()
	assert_true(sim.apply_transition(1, "ankle_lock", PositionLibrary.FAILED))
	assert_eq(sim.situation.position, "side_control", "he falls back for the foot and the top fighter walks past")
	assert_eq(sim.situation.role(0), PositionLibrary.TOP)
	assert_almost_eq(sim.round_points()[0] - before[0], Judging.ADVANCE_POINTS_PER_CONTROL * 0.5, 0.001, "full guard 1.0 to side control 1.5")
	assert_eq(sim.round_points()[1], before[1])
	assert_eq(sim.fighters[0].advances, 1)
	assert_eq(sim.fighters[1].escapes, 0, "missing a leg lock isn't getting out")
	assert_true(_events(sim, FightEvent.POSITION_CHANGED)[-1].data.get("failed", false))
	assert_string_contains(FightLogFormatter.line(_events(sim, FightEvent.POSITION_CHANGED)[-1], sim), "misses and costs the position")


func test_a_rolled_ankle_lock_that_misses_costs_the_position() -> void:
	var ends := {}
	for n in SEEDS:
		var sim: FightSim = _red_on_top("half_guard", _fighter("Red", { "submission_defense": 100, "scrambles": 100 }), _fighter("Blue", { "submissions": 0, "scrambles": 0 }, ["ankle_lock"]), SEED + n)
		_queue(sim, 1, "ankle_lock")
		_ticks(sim, 7)
		ends[sim.situation.position] = true
	assert_true(ends.has("side_control"), "a miss from half guard: side control")
	assert_true(ends.has(PositionLibrary.SCRAMBLE), "and when it half works, a scramble")


func test_a_kneebar_from_on_top_that_misses_puts_the_attacker_underneath() -> void:
	var sim: FightSim = _red_on_top("half_guard", _fighter("Red", {}, ["kneebar"]), _fighter("Blue"))
	var before: Array[float] = sim.round_points()
	assert_true(sim.apply_transition(0, "kneebar", PositionLibrary.FAILED))
	assert_eq(sim.situation.position, "full_guard")
	assert_eq(sim.situation.role(0), PositionLibrary.BOTTOM, "he rolled for the leg and lost the top")
	assert_eq(sim.situation.role(1), PositionLibrary.TOP)
	assert_almost_eq(sim.round_points()[1] - before[1], Judging.TAKEDOWN_POINTS, 0.001, "ending up on top scores like a takedown")


func test_getting_out_of_a_leg_lock_ends_in_a_scramble() -> void:
	var sim: FightSim = _red_on_top("full_guard", _fighter("Red", { "submission_defense": 100, "scrambles": 100 }), _fighter("Blue", { "submissions": 0, "scrambles": 0 }, ["ankle_lock"]))
	assert_true(sim._lock_in(1, _actions.get_action("ankle_lock")))
	_ticks(sim, 60)
	assert_false(sim.is_over())
	assert_eq(sim.situation.position, PositionLibrary.SCRAMBLE)


func test_the_heel_hook_moves_the_danger_further_each_beat() -> void:
	var sim: FightSim = _red_on_top("full_guard", _fighter("Red"), _fighter("Blue", {}, ["heel_hook"]))
	assert_eq(sim.struggle_step("heel_hook"), 30.0, "it goes fast: a tap or out in fewer beats")
	assert_eq(sim.struggle_step("ankle_lock"), FightSim.STRUGGLE_STEP)
	assert_true(sim._lock_in(1, _actions.get_action("heel_hook")))
	var start: float = float(sim.hold().danger)
	_ticks(sim, FightSim.STRUGGLE_BEAT_TICKS + 1)
	var beat: FightEvent = _events(sim, FightEvent.SUBMISSION_BEAT)[0]
	assert_eq(absf(float(beat.data.danger) - start), 30.0)


func test_a_much_better_leg_locker_makes_him_tap_and_the_harness_counts_it() -> void:
	var sim: FightSim = _red_on_top("full_guard", _fighter("Red", WORST), _fighter("Blue", BEST, ["heel_hook"]))
	assert_true(sim._lock_in(1, _actions.get_action("heel_hook")))
	_ticks(sim, 60)
	assert_true(sim.is_over())
	var end: FightEvent = sim.events[-1]
	assert_eq(end.data.result, FightSim.RESULT_SUB)
	assert_eq(end.data.why, "heel_hook")
	var row: Dictionary = FightSummary.of(sim)
	assert_eq(row.leg_lock_finish, 1)
	assert_eq(row.leg_locked_blue, 1)
	assert_eq(row.leg_locks_red, 0)


func test_amateur_rules_ban_the_heel_hook_but_not_the_ankle_lock() -> void:
	for id: String in ["amateur_adult", "amateur_teen"]:
		var rules := Ruleset.load_id(id)
		assert_false(rules.allows_action(_actions.get_action("heel_hook")), id)
		assert_true(rules.allows_action(_actions.get_action("ankle_lock")), id)
		assert_true(rules.allows_action(_actions.get_action("kneebar")), id)
	assert_true(Ruleset.load_id("pro").allows_action(_actions.get_action("heel_hook")))
	var amateur: FightSim = _red_on_top("full_guard", _fighter("Red"), _fighter("Blue", {}, ["heel_hook", "ankle_lock"]), SEED, Ruleset.load_id("amateur_adult"))
	assert_ne(amateur.why_not(1, "heel_hook"), "")
	assert_eq(amateur.why_not(1, "ankle_lock"), "")


# --- The fighter AI -------------------------------------------------------------------

func test_in_a_scramble_the_ai_goes_for_a_leg_lock_without_waiting_for_an_opening() -> void:
	var tried: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top(PositionLibrary.SCRAMBLE, _fighter("Red", { "submissions": 90 }, ["ankle_lock"], 0.03), _fighter("Blue"), SEED + n)
		_ticks(sim, 30)
		if _starts(sim, 0).has("ankle_lock"):
			tried += 1
	assert_gt(tried, 0, "legs everywhere: he dives for the foot now and then")
	assert_lt(tried, SEEDS, "but not every scramble")


func test_underneath_the_ai_waits_for_him_to_posture_up_before_an_ankle_lock() -> void:
	for n in 5:
		var sim: FightSim = _red_on_top("full_guard", _fighter("Red"), _fighter("Blue", { "submissions": 90 }, ["ankle_lock"], 0.03), SEED + n)
		_ticks(sim, 600)
		assert_does_not_have(_starts(sim, 1), "ankle_lock", "nothing to attack while he stays down")


func test_on_top_of_half_guard_the_ai_sometimes_takes_a_kneebar_as_he_escapes() -> void:
	var took: int = 0
	for n in SEEDS:
		var sim: FightSim = _red_on_top("half_guard", _fighter("Red", { "submissions": 90 }, ["kneebar"], 0.03), _fighter("Blue"), SEED + n)
		_queue(sim, 1, "recover_guard")
		_ticks(sim, 12)
		if _starts(sim, 0).has("kneebar"):
			took += 1
	assert_gt(took, 0, "the escape leaves a leg behind")
	assert_lt(took, SEEDS)


# --- The fighters ---------------------------------------------------------------------

func test_only_the_sambo_and_bjj_fighters_know_leg_locks_and_only_the_bjj_fighter_the_heel_hook() -> void:
	var roster := FighterLibrary.load_dir()
	for id: String in roster.ids():
		var knows: Array[String] = []
		for move: String in roster.make(id).repertoire:
			if _actions.has(move) and ActionLibrary.is_leg_lock(_actions.get_action(move)):
				knows.append(move)
		match id:
			"sambo":
				assert_eq(knows, ["ankle_lock", "kneebar"] as Array[String], "sport sambo bans the heel hook")
			"bjj":
				assert_eq(knows, ["ankle_lock", "heel_hook"] as Array[String])
			_:
				assert_eq(knows, [] as Array[String], id)


func test_the_sambo_fighter_goes_for_leg_locks_in_real_fights() -> void:
	var roster := FighterLibrary.load_dir()
	var tried: int = 0
	for n in 6:
		var sim := FightSim.new(SEED + n, roster.make_pair("sambo", "boxer"), _actions)
		sim.run_to_end()
		tried += sim.fighters[0].leg_locks_tried
	assert_gt(tried, 0)
