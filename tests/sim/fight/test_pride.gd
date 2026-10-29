extends GutTest
## The PRIDE ruleset (D141, docs/01 §33): a 10-minute first round, soccer kicks and stomps
## on a knocked-down fighter, and knees to the head on the ground. Pro and amateur rules
## stay unified rules.

const SEED: int = 20261029
const SEEDS: int = 40

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart, under these rules.
func _pair(rules_id: String, red_stats: Dictionary = {}, blue_stats: Dictionary = {}, gap: float = 1.2, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, Ruleset.load_id(rules_id))
	sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	return sim


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


## Knocks Blue down where he stands, as a knockdown does (FightSim._knockdown).
func _knock_down(sim: FightSim) -> void:
	sim.fighters[1].down_ticks = FightSim.DOWN_TICKS
	sim.fighters[1].rocked_ticks = sim.rocked_duration(sim.fighters[1])


# --- The rounds ------------------------------------------------------------------

func test_a_pride_fight_has_a_ten_minute_first_round_then_two_of_five() -> void:
	var rules := Ruleset.load_id("pride")
	assert_eq(rules.round_lengths, [600, 300, 300] as Array[int])
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, [], 0.0), FighterState.new("Blue", {}, [], 0.0)], _actions, rules)
	var round_ends: Array[int] = []
	while not sim.is_over():
		var before: int = sim.clock.current_round
		sim.tick()
		if sim.clock.current_round != before or sim.is_over():
			round_ends.append(sim.now)
	assert_eq(round_ends, [6000, 9000, 12000] as Array[int], "10:00, then 5:00 and 5:00 (ticks of 0.1 s)")


func test_the_clock_knows_where_each_round_starts_when_they_differ() -> void:
	var clock := FightClock.new(3, 300, [600, 300, 300] as Array[int])
	assert_eq(clock.ticks_in_round(1), 6000)
	assert_eq(clock.ticks_in_round(2), 3000)
	assert_eq(clock.round_start_tick(1), 0)
	assert_eq(clock.round_start_tick(3), 9000)
	assert_eq(clock.display(), "R1 10:00")
	var even := FightClock.new(3, 300)
	assert_eq(even.round_start_tick(3), 6000, "every round the same when there are no round_lengths")


func test_the_feed_times_an_event_from_the_start_of_its_own_round() -> void:
	var sim: FightSim = _pair("pride")
	var e := FightEvent.new(6015, 2, FightEvent.ROCKED, 1, {})
	assert_eq(FightLogFormatter.time_label(e, 300, sim.clock.round_start_tick(2)), "R2 0:01.5", "round 2 starts at 10:00 of fight time")
	assert_eq(FightFeed.clock_label(e, sim), "4:59")


func test_pro_and_amateur_rounds_are_unchanged() -> void:
	for id in ["pro", "amateur_adult", "amateur_teen"]:
		assert_true(Ruleset.load_id(id).round_lengths.is_empty(), id)


# --- Soccer kicks and stomps ---------------------------------------------------------

func test_soccer_kicks_and_stomps_are_only_legal_under_pride_rules() -> void:
	for id in ["soccer_kick", "stomp"]:
		for rules in ["pro", "amateur_adult", "amateur_teen"]:
			assert_false(Ruleset.load_id(rules).allows_action(_actions.get_action(id)), "%s under %s" % [id, rules])
		assert_true(Ruleset.load_id("pride").allows_action(_actions.get_action(id)), "%s under PRIDE" % id)
		assert_true(_actions.get_action(id).get("basic", false), "everyone knows how to kick a man who's down")


func test_a_soccer_kick_needs_him_down() -> void:
	var sim: FightSim = _pair("pride")
	assert_eq(sim.odds(0, "soccer_kick"), 0.0, "standing up, there's nothing to kick")
	_knock_down(sim)
	assert_has(sim.active_flags(1), "DOWN")
	assert_gt(sim.odds(0, "soccer_kick"), 0.5, "on the floor, rocked, he can't do much about it")


func test_only_a_soccer_kick_or_a_stomp_lands_on_a_downed_fighter() -> void:
	var sim: FightSim = _pair("pride", { "power": 100 })
	_knock_down(sim)
	assert_true(sim.submit(FightCommand.queue_action(0, 0, "cross")))
	_ticks(sim, 6)
	var missed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_MISSED, 0)
	assert_eq(missed.size(), 1)
	assert_eq(missed[0].data.get("reason", ""), "opponent down", "a punch at a man on the floor misses, PRIDE or not")
	var kicked: int = 0
	for n in SEEDS:
		var k: FightSim = _pair("pride", { "kicking": 100, "power": 100 }, {}, 1.2, SEED + n)
		_knock_down(k)
		assert_true(k.submit(FightCommand.queue_action(0, 0, "soccer_kick")))
		_ticks(k, 6)
		kicked += _events(k, FightEvent.STRIKE_LANDED, 0).size()
	assert_gt(kicked, SEEDS / 2, "the soccer kick lands on him most of the time")


func test_a_soccer_kick_is_refused_under_pro_rules() -> void:
	var sim: FightSim = _pair("pro")
	_knock_down(sim)
	sim.submit(FightCommand.queue_action(0, 0, "soccer_kick"))
	sim.tick()
	assert_eq(sim.events[0].type, FightEvent.COMMAND_REJECTED)


func test_kicked_while_down_is_no_second_knockdown_but_can_end_it() -> void:
	var ko: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair("pride", { "kicking": 100, "power": 100 }, { "chin": 20 }, 1.2, SEED + n)
		_knock_down(sim)
		sim.submit(FightCommand.queue_action(0, 0, "soccer_kick"))
		_ticks(sim, 6)
		assert_eq(sim.fighters[1].knockdowns, 0, "seed %d: he's already down: no knockdown is scored for it" % (SEED + n))
		if sim.is_over():
			ko += 1
	assert_gt(ko, 0, "a soccer kick on a downed man with a weak chin ends some fights")


# --- Knees on the ground ---------------------------------------------------------------

func _ground_knee_target(rules_id: String) -> String:
	for n in SEEDS:
		var sim: FightSim = _pair(rules_id, { "top_control": 100, "power": 100 }, { "guard": 0 }, 1.2, SEED + n)
		assert_true(sim.apply_transition(0, "double_leg"))
		assert_true(sim.apply_transition(0, "guard_pass"))
		assert_eq(sim.situation.position, "side_control")
		assert_true(sim.submit(FightCommand.queue_action(0, 0, "ground_knee")), "seed %d" % (SEED + n))
		_ticks(sim, 6)
		var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
		if not landed.is_empty():
			return String(landed[0].data.target)
	return ""


func test_a_knee_on_the_ground_goes_to_the_head_only_under_pride_rules() -> void:
	assert_eq(_ground_knee_target("pride"), "head")
	assert_eq(_ground_knee_target("pro"), "body", "unified rules: knees to the body of a grounded man only")
	assert_eq(_ground_knee_target("amateur_adult"), "body")


# --- The fighter AI ---------------------------------------------------------------------

func test_the_ai_kicks_a_knocked_down_man_under_pride_rules_and_never_under_pro() -> void:
	var counts: Dictionary = { "pride": 0, "pro": 0 }
	for rules: String in counts:
		for n in SEEDS:
			var sim: FightSim = FightSim.new(SEED + n, _roster.make_pair("kicker", "boxer"), _actions, Ruleset.load_id(rules))
			sim.fighters[0].pos = Vector2(-0.6, 0.0)
			sim.fighters[1].pos = Vector2(0.6, 0.0)
			_knock_down(sim)
			_ticks(sim, FightSim.DOWN_TICKS)
			for e in _events(sim, FightEvent.ACTION_PHASE, 0):
				if e.data.phase == "telegraph" and (e.data.action_id == "soccer_kick" or e.data.action_id == "stomp"):
					counts[rules] += 1
					assert_eq(e.data.why, "while he's down")
	assert_gt(counts.pride, SEEDS / 4, "PRIDE: he follows the knockdown up")
	assert_eq(counts.pro, 0, "pro: he waits for him to get up")


# --- Whole-fight judging -------------------------------------------------------------

func test_a_judge_looks_at_the_effort_to_finish_first() -> void:
	var pick: Dictionary = Judging.whole_fight_pick({ "finish": [120.0, 80.0], "control": [0.0, 90.0], "aggression": [10.0, 60.0] })
	assert_eq(pick, { "winner": 0, "on": Judging.FINISH }, "more done to finish it beats more control and more aggression")


func test_control_decides_only_when_the_effort_to_finish_is_close() -> void:
	var pick: Dictionary = Judging.whole_fight_pick({ "finish": [100.0, 95.0], "control": [10.0, 40.0], "aggression": [50.0, 20.0] })
	assert_eq(pick, { "winner": 1, "on": Judging.CONTROL }, "within 10% on the finish: the one who held him down")


func test_aggression_decides_when_finish_and_control_are_both_close() -> void:
	var pick: Dictionary = Judging.whole_fight_pick({ "finish": [100.0, 95.0], "control": [20.0, 21.0], "aggression": [50.0, 49.0] })
	assert_eq(pick, { "winner": 0, "on": Judging.AGGRESSION }, "any edge in aggression settles it")
	var nothing: Dictionary = Judging.whole_fight_pick({ "finish": [0.0, 0.0], "control": [0.0, 0.0], "aggression": [0.0, 0.0] })
	assert_eq(int(nothing.winner), -1, "only a fight where nothing at all separates them is even")


func test_judges_picks_make_the_verdict() -> void:
	assert_eq(Judging.whole_fight_decision([1, 1, 1]), { "result": Judging.UNANIMOUS, "winner": 1 })
	assert_eq(Judging.whole_fight_decision([0, 1, 0]), { "result": Judging.SPLIT, "winner": 0 })
	assert_eq(Judging.whole_fight_decision([0, -1, 0]), { "result": Judging.MAJORITY, "winner": 0 })


func test_a_takedown_counts_as_control_not_as_an_effort_to_finish() -> void:
	var sim: FightSim = _pair("pride")
	assert_true(sim.apply_transition(0, "double_leg"))
	var scores: Dictionary = sim.fight_scores()
	assert_almost_eq(float(scores.control[0]), Judging.TAKEDOWN_POINTS, 0.0001)
	assert_eq(float(scores.finish[0]), 0.0)


## The first fight of `red` vs `blue` from SEED that goes the distance under these rules.
func _distance_fight(rules_id: String, red: String = "kicker", blue: String = "boxer") -> FightSim:
	for n in SEEDS:
		var sim := FightSim.new(SEED + n, _roster.make_pair(red, blue), _actions, Ruleset.load_id(rules_id))
		sim.run_to_end()
		if sim.clock.is_fight_over():
			return sim
	return null


func test_a_pride_fight_that_goes_the_distance_has_no_round_scores() -> void:
	var sim: FightSim = _distance_fight("pride")
	assert_not_null(sim, "one of %d fights goes the distance" % SEEDS)
	var last: FightEvent = sim.events[-1]
	assert_eq(_events(sim, FightEvent.ROUND_ENDED).size(), 3)
	for e in _events(sim, FightEvent.ROUND_ENDED):
		assert_false(e.data.has("cards"), "round %d: no 10-9s under PRIDE rules" % e.round_number)
	assert_eq(last.data.judges.size(), Judging.JUDGES, "three judges each pick a winner")
	assert_false(last.data.has("cards"))
	assert_string_contains(FightLogFormatter.result_text(last, sim), " on ")


func test_pro_fights_are_still_scored_round_by_round() -> void:
	var sim: FightSim = _distance_fight("pro")
	assert_not_null(sim)
	for e in _events(sim, FightEvent.ROUND_ENDED):
		assert_eq(e.data.cards.size(), Judging.JUDGES)
	assert_true(sim.events[-1].data.has("cards"))
