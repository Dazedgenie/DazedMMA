extends GutTest
## Clinch, takedowns and the trimmed ground game (issue #15, docs/01 §21): the
## catch-kick through the ONE_LEG window, sprawls and knees punishing a shot (D29),
## getting up and scrambles, the clinch, and what each position does per tick.

const SEED: int = 20261025
## Enough seeds that a 95% move works on most of them and a 10% outcome turns up.
const SEEDS: int = 40

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart in the middle of the cage.
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, gap: float = 1.8, fight_seed: int = SEED, rules: Variant = 1) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, rules, 300)
	sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
	return sim


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)))


func _ticks(sim: FightSim, n: int) -> void:
	for k in n:
		sim.tick()


func _events(sim: FightSim, type: String, actor: int = FightEvent.NO_ACTOR) -> Array[FightEvent]:
	var out: Array[FightEvent] = []
	for e in sim.events:
		if e.type == type and (actor == FightEvent.NO_ACTOR or e.actor == actor):
			out.append(e)
	return out


func _bonus_names(odds: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for b: Dictionary in odds.bonuses:
		out.append(b.name)
	return out


## Red takes Blue down (no roll): full guard, Red on top.
func _on_the_ground(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	var sim: FightSim = _pair(red_stats, blue_stats, 1.8, fight_seed)
	assert_true(sim.apply_transition(0, "double_leg"))
	return sim


# --- The catch-kick (docs/01 §5.1) --------------------------------------------

func test_a_catch_kick_timed_into_the_kick_takes_it_to_the_ground() -> void:
	# Red's body kick is on one leg from tick 3 to 11; Blue's catch makes contact a tick after it starts.
	var caught: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({}, { "takedowns": 100, "speed": 100 }, 1.8, SEED + n)
		_queue(sim, 0, 0, "body_kick")
		_queue(sim, 4, 1, "catch_kick_single")
		_ticks(sim, 20)
		var outcome: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 1)
		outcome.append_array(_events(sim, FightEvent.GRAPPLE_STOPPED, 1))
		assert_eq(outcome.size(), 1, "one roll for the catch")
		assert_has(_bonus_names(outcome[0].data.odds), "ONE_LEG", "caught on one leg")
		if outcome[0].type == FightEvent.GRAPPLE_WON:
			caught += 1
			assert_eq(sim.situation.position, "full_guard")
			assert_eq(sim.role(1), "top")
			assert_eq(sim.fighters[1].takedowns_landed, 1)
	assert_gt(caught, SEEDS * 0.8, "95%% odds should work almost every time (%d of %d)" % [caught, SEEDS])


func test_a_catch_kick_with_no_kick_to_catch_finds_nothing() -> void:
	var sim: FightSim = _pair({}, { "takedowns": 100 })
	_queue(sim, 0, 0, "body_kick")
	_queue(sim, 0, 1, "catch_kick_single")  # Contact at tick 1: the kick is still only a telegraph.
	_ticks(sim, 20)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 1)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0].data.reason, "nothing to catch")
	assert_eq(stopped[0].data.odds.missing, "ONE_LEG", "the log can say what was missing")
	assert_true(sim.situation.is_standing())


func test_a_catch_kick_too_late_finds_nothing_either() -> void:
	var sim: FightSim = _pair({}, { "takedowns": 100 })
	_queue(sim, 0, 0, "body_kick")
	_queue(sim, 11, 1, "catch_kick_single")  # Contact at tick 12: the kicker is back on two feet.
	_ticks(sim, 25)
	assert_eq(_events(sim, FightEvent.GRAPPLE_STOPPED, 1)[0].data.reason, "nothing to catch")


# --- Takedowns ------------------------------------------------------------------

func test_a_shot_out_of_range_comes_up_short() -> void:
	var sim: FightSim = _pair({}, {}, 2.8)  # Long range: a double leg needs mid or closer.
	_queue(sim, 0, 0, "double_leg")
	_ticks(sim, 15)
	assert_eq(_events(sim, FightEvent.GRAPPLE_STOPPED, 0)[0].data.reason, "out of range")
	assert_true(sim.situation.is_standing())


func test_a_takedown_is_rolled_at_the_end_of_the_drive_on_the_odds_at_contact() -> void:
	var sim: FightSim = _pair({ "takedowns": 100 })
	_queue(sim, 0, 0, "double_leg")
	_ticks(sim, 10)  # Telegraph 3 + wind-up 2: contact at tick 5, the drive lasts 5 ticks.
	assert_not_null(sim.fighters[0].grip, "made contact, not rolled yet")
	assert_true(sim.situation.is_standing())
	sim.tick()
	assert_null(sim.fighters[0].grip)
	assert_eq(_events(sim, FightEvent.GRAPPLE_WON, 0).size() + _events(sim, FightEvent.GRAPPLE_STOPPED, 0).size(), 1)


func test_a_landed_takedown_scores_with_the_judges() -> void:
	var sim: FightSim = _pair({}, {}, 1.8, SEED, Ruleset.pro_with(1, 10))
	sim.apply_transition(1, "double_leg")
	_ticks(sim, 100)
	var cards: Array = _events(sim, FightEvent.ROUND_ENDED)[0].data.cards
	for card: Array in cards:
		assert_eq(card, [9, 10], "a takedown and the control after it win an otherwise empty round")


func test_some_shots_half_work_and_end_in_a_scramble() -> void:
	var scrambles: int = 0
	for n in 60:
		var sim: FightSim = _pair({}, {}, 1.8, SEED + n)
		_queue(sim, 0, 0, "double_leg")
		_ticks(sim, 12)
		for e in _events(sim, FightEvent.GRAPPLE_WON, 0):
			if e.data.result == "partial":
				scrambles += 1
				assert_eq(sim.situation.position, "scramble")
				assert_eq(sim.role(0), "neutral")
	assert_gt(scrambles, 0, "10% of the rolls just past the odds end in a scramble")


# --- Punishing the shot (D29) ---------------------------------------------------

func test_a_sprawl_in_time_stuffs_the_shot_and_leaves_the_shooter_stuck_head_low() -> void:
	var stuffed: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({}, { "takedown_defense": 100, "speed": 100 }, 1.8, SEED + n)
		_queue(sim, 0, 0, "double_leg")
		_queue(sim, 3, 1, "sprawl")  # Sprawl active from tick 4: there as the shot arrives at tick 5.
		_ticks(sim, 6)
		var met: Array[FightEvent] = _events(sim, FightEvent.SPRAWLED, 1)
		assert_eq(met.size(), 1, "the sprawl meets the shot once")
		assert_has(_bonus_names(met[0].data.odds), "HEAD_LOW")
		if met[0].data.worked:
			stuffed += 1
			assert_eq(_events(sim, FightEvent.GRAPPLE_STOPPED, 0)[0].data.reason, "sprawled on")
			assert_has(sim.active_flags(0), "HEAD_LOW", "stuck under the sprawl")
			assert_eq(sim.fighters[0].phase, "recovery")
			assert_gt(sim.fighters[0].phase_ticks_left, _actions.phase_ticks("double_leg", "recovery"), "and longer than a normal recovery")
	assert_gt(stuffed, SEEDS * 0.8)


func test_a_sprawl_too_early_is_spent_before_the_shot_arrives() -> void:
	var sim: FightSim = _pair({}, { "takedown_defense": 100 })
	_queue(sim, 0, 0, "double_leg")
	_queue(sim, 0, 1, "sprawl")  # Its active phase is over by tick 4.
	_ticks(sim, 15)
	assert_eq(_events(sim, FightEvent.SPRAWLED).size(), 0)


## A knee from Blue landing at tick 6, in Red's double leg's drive (head low), on the first
## seed where the 95% knee lands.
func _knee_into_a_shot(rules: Variant = 1) -> FightSim:
	for n in SEEDS:
		var sim: FightSim = _pair({}, { "clinch_striking": 100, "power": 100 }, 1.2, SEED + n, rules)
		_queue(sim, 0, 0, "double_leg")
		_queue(sim, 2, 1, "knee")
		_ticks(sim, 8)
		if not _events(sim, FightEvent.STRIKE_LANDED, 1).is_empty():
			return sim
	return null


func test_a_knee_into_the_shot_goes_to_the_head_harder_and_stops_it() -> void:
	var sim: FightSim = _knee_into_a_shot()
	assert_not_null(sim)
	var landed: FightEvent = _events(sim, FightEvent.STRIKE_LANDED, 1)[0]
	assert_eq(landed.data.target, "head", "the lowered head")
	assert_eq(landed.data.into, "double_leg")
	assert_eq(landed.data.damage, roundi(9 * 1.5 * 1.5), "base 9 × Power 100 × 1.5 into the shot")
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 0)
	assert_eq(stopped[0].data.reason, "stopped")
	assert_eq(stopped[0].data.by_action, "knee")
	assert_true(sim.situation.is_standing(), "the shot never got there")


func test_a_knee_into_the_shot_can_drop_him_on_the_spot() -> void:
	var drops: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({}, { "clinch_striking": 100, "power": 100 }, 1.2, SEED + n)
		_queue(sim, 0, 0, "double_leg")
		_queue(sim, 2, 1, "knee")
		_ticks(sim, 8)
		var rocked: bool = not _events(sim, FightEvent.ROCKED, 0).is_empty()
		assert_false(rocked, "caught coming in, a rock is a knockdown straight away")
		drops += _events(sim, FightEvent.KNOCKDOWN, 0).size()
	assert_gt(drops, 0)


func test_a_jab_landed_as_they_come_in_stops_a_clinch_entry_or_the_start_of_a_shot() -> void:
	# D114: COMING_IN through a clinch entry and a double leg's first step; the jab lands 0.2 s in.
	for entry: String in ["clinch_entry", "double_leg"]:
		var stopped: int = 0
		for n in SEEDS:
			var sim: FightSim = _pair({}, { "boxing": 100, "speed": 100 }, 1.2, SEED + n)
			_queue(sim, 0, 0, entry)
			_queue(sim, 0, 1, "jab")
			_ticks(sim, 4)
			var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 1)
			if landed.is_empty():
				continue
			assert_has(_bonus_names(landed[0].data.odds), "COMING_IN")
			assert_eq(landed[0].data.get("into", ""), entry)
			var why: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 0)
			assert_eq(why[0].data.by_action, "jab")
			assert_true(sim.situation.is_standing())
			stopped += 1
		assert_gt(stopped, SEEDS / 2, "%s: most jabs land (%d of %d)" % [entry, stopped, SEEDS])


func test_where_knees_to_the_head_are_banned_the_knee_into_a_shot_stays_on_the_body() -> void:
	var sim: FightSim = _knee_into_a_shot(Ruleset.load_id("amateur_teen"))
	assert_not_null(sim)
	assert_eq(_events(sim, FightEvent.STRIKE_LANDED, 1)[0].data.target, "body")


# --- On the ground ----------------------------------------------------------------

func test_only_the_fighter_underneath_can_get_up() -> void:
	var sim: FightSim = _on_the_ground()
	assert_eq(sim.why_not(0, "get_up"), "not possible from the top")
	assert_eq(sim.why_not(1, "get_up"), "")
	assert_eq(sim.why_not(1, "jab"), "not possible from this position", "the jab is a standing strike; ground strikes are thrown from the top (D121)")


func test_getting_up_stands_them_up_a_gap_apart() -> void:
	var up: int = 0
	for n in SEEDS:
		var sim: FightSim = _on_the_ground({ "top_control": 0 }, { "scrambles": 100, "takedown_defense": 100 }, SEED + n)
		_queue(sim, 0, 1, "get_up")
		_ticks(sim, 12)
		if not _events(sim, FightEvent.GRAPPLE_WON, 1).is_empty() and sim.situation.is_standing():
			up += 1
			assert_almost_eq(sim.distance(), Octagon.MIN_GAP, 0.0001)
	assert_gt(up, SEEDS * 0.8)


func test_getting_up_with_your_back_on_the_fence_is_easier() -> void:
	var sim: FightSim = _pair()
	sim.fighters[1].pos = Vector2(4.1, 0.0)  # Blue's back on the fence.
	sim.fighters[0].pos = Vector2(2.6, 0.0)
	sim.apply_transition(0, "double_leg")
	var b: OddsBreakdown = sim.odds_breakdown(1, "get_up")
	assert_has(_bonus_names(b.to_dict()), "own BACK_TO_CAGE", "wall-walking")
	assert_almost_eq(b.chance, 0.25 + 0.15, 0.0001)


func test_a_scramble_ends_on_the_feet_or_with_someone_on_top() -> void:
	var sim: FightSim = _pair()
	sim.situation.set_to(sim.positions.get_position("scramble"), ["neutral", "neutral"] as Array[String])
	assert_eq(sim.why_not(0, "get_up"), "")
	assert_eq(sim.why_not(1, "scramble"), "")
	var t: Dictionary = sim.transition_for(1, "scramble")
	assert_eq(t.to, "full_guard")
	assert_eq(t.roles.actor, "top")
	assert_eq(sim.transition_for(0, "get_up").to, "standing")


func test_on_top_you_score_control_and_underneath_you_tire() -> void:
	var sim: FightSim = _on_the_ground()
	for f in sim.fighters:
		f.stamina = 50.0
	var points: Array[float] = sim._round_points.duplicate()
	_ticks(sim, 10)
	assert_almost_eq(sim._round_points[0] - points[0], 1.0 * Judging.CONTROL_POINTS_PER_S, 0.0001, "full guard top: control 1.0")
	assert_almost_eq(sim._round_points[1] - points[1], 0.2 * Judging.CONTROL_POINTS_PER_S, 0.0001, "bottom: 0.2")
	assert_almost_eq(sim.fighters[0].stamina, 50.0 + 1.2 - 0.2, 0.001, "breathing 1.2 a second, top drains 0.2")
	assert_almost_eq(sim.fighters[1].stamina, 50.0 + 1.2 - 0.3, 0.001, "bottom drains 0.3")


func test_ending_up_on_top_scores_a_takedown() -> void:
	var sim: FightSim = _pair()
	sim.apply_transition(1, "double_leg")
	assert_almost_eq(sim._round_points[1], Judging.TAKEDOWN_POINTS, 0.0001)
	assert_eq(sim.fighters[1].takedowns_landed, 1)


# --- The clinch ---------------------------------------------------------------------

func test_a_clinch_entry_ties_them_up_where_knees_work_and_a_break_separates_them() -> void:
	var tied: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "clinch_control": 100, "strength": 100 }, {}, 1.2, SEED + n)
		_queue(sim, 0, 0, "clinch_entry")
		_ticks(sim, 8)
		if sim.situation.position != "clinch":
			continue
		tied += 1
		assert_eq(sim.band(), Octagon.BAND_CLINCH)
		assert_almost_eq(sim.distance(), FightSim.TANGLED_GAP, 0.0001)
		assert_eq(sim.why_not(1, "knee"), "", "knees work in the clinch")
		assert_eq(sim.why_not(1, "jab"), "not possible from this position")
		_queue(sim, 8, 0, "clinch_break")
		_ticks(sim, 6)
		if not _events(sim, FightEvent.GRAPPLE_WON, 0).filter(func(e: FightEvent) -> bool: return e.data.action_id == "clinch_break").is_empty():
			assert_true(sim.situation.is_standing())
			assert_almost_eq(sim.distance(), Octagon.MIN_GAP, 0.0001)
	assert_gt(tied, SEEDS * 0.8)


func test_a_knockdown_in_the_clinch_separates_them() -> void:
	var sim: FightSim = _pair()
	sim.apply_transition(0, "clinch_entry")
	sim.fighters[1].rocked_ticks = 10
	sim._knockdown(0, 0.5)
	assert_true(sim.situation.is_standing())
	var apart: Array[FightEvent] = _events(sim, FightEvent.POSITION_CHANGED)
	assert_eq(apart.back().data.action_id, "", "nobody's move: they come apart")



func test_a_knee_that_drops_a_shot_from_the_clinch_ends_the_knee_cleanly() -> void:
	var drops: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({}, { "clinch_striking": 100, "power": 100 }, 1.2, SEED + n)
		sim.apply_transition(0, "clinch_entry")
		_queue(sim, 0, 0, "double_leg")
		_queue(sim, 2, 1, "knee")
		_ticks(sim, 12)
		if _events(sim, FightEvent.KNOCKDOWN, 0).is_empty():
			continue
		drops += 1
		assert_true(sim.situation.is_standing(), "the knockdown breaks the clinch")
		for e in _events(sim, FightEvent.ACTION_PHASE, 1):
			assert_ne(e.data.action_id, "", "no phantom move after the knee is over")
	assert_gt(drops, 0)

# --- The fighter AI tied up -----------------------------------------------------

func _fighter(fighter_name: String, p_stats: Dictionary, moves: Array[String], style: Dictionary = {}) -> FighterState:
	return FighterState.new(fighter_name, p_stats, moves, FighterState.DEFAULT_WORK_RATE, StyleLeanings.new(style))


func _starts(sim: FightSim, actor: int) -> Array[String]:
	var out: Array[String] = []
	for e in _events(sim, FightEvent.ACTION_PHASE, actor):
		if e.data.phase == "telegraph":
			out.append(e.data.action_id)
	return out


func test_the_fighter_underneath_works_to_get_up_and_the_one_on_top_grounds_and_pounds() -> void:
	var sim := FightSim.new(SEED, [FighterState.new("Top", {}, [], 0.0), _fighter("Bottom", {}, ["jab"])], _actions, 1, 300)
	sim.apply_transition(0, "double_leg")
	_ticks(sim, 600)
	assert_has(_starts(sim, 1), "get_up", "everyone knows how to get up, whatever their techniques")
	var pounder := FightSim.new(SEED, [_fighter("Top", {}, ["jab", "double_leg"]), FighterState.new("Bottom", {}, [], 0.0)], _actions, 1, 300)
	pounder.apply_transition(0, "double_leg")
	_ticks(pounder, 600)
	assert_gt(_starts(pounder, 0).size(), 0, "on top they ground and pound (D121)")
	for id in _starts(pounder, 0):
		assert_eq(id, "ground_punch", "everyone knows the ground punch; the jab is for standing")


func test_strikers_break_the_clinch_and_grapplers_work_in_it() -> void:
	var roster := FighterLibrary.load_dir()
	var moves := { "kicker": {}, "wrestler": {} }
	for id: String in moves:
		for n in 10:
			var sim := FightSim.new(SEED + n, [roster.make(id), FighterState.new("Statue", {}, [], 0.0)], _actions, 1, 300)
			sim.apply_transition(0, "clinch_entry")
			_ticks(sim, 300)
			var starts: Array[String] = _starts(sim, 0)
			if not starts.is_empty():
				moves[id][starts[0]] = moves[id].get(starts[0], 0) + 1
	assert_gt(moves.kicker.get("clinch_break", 0), moves.kicker.get("knee", 0), "the Kicker wants out: %s" % [moves.kicker])
	assert_gt(moves.wrestler.get("double_leg", 0), moves.wrestler.get("clinch_break", 0), "the Wrestler takes it down: %s" % [moves.wrestler])


func test_only_fighters_who_like_it_and_have_something_there_tie_up() -> void:
	var roster := FighterLibrary.load_dir()
	var sim := FightSim.new(SEED, roster.make_pair("kicker", "boxer"), _actions)
	sim.run_to_end()
	assert_does_not_have(_starts(sim, 0), "clinch_entry", "the Kicker keeps it at range")
	assert_does_not_have(_starts(sim, 1), "clinch_entry", "the Boxer has nothing to do in the clinch")
	var wrestler := FightSim.new(SEED, roster.make_pair("wrestler", "boxer"), _actions)
	wrestler.run_to_end()
	assert_has(_starts(wrestler, 0), "clinch_entry")
	assert_gt(wrestler.fighters[0].takedowns_landed, 0, "and takes him down")


func test_a_fighter_who_reads_a_shot_sprawls_on_it() -> void:
	var sim := FightSim.new(SEED, [FighterState.new("Shooter", {}, [], 0.0), _fighter("Reader", { "fight_iq": 100, "takedown_defense": 100 }, ["jab"])], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	for k in 20:
		_queue(sim, 40 * k, 0, "double_leg")
	for k in 800:
		sim.tick()
		if not sim.situation.is_standing():
			sim._break_apart(1)
	assert_gt(_events(sim, FightEvent.SPRAWLED, 1).size(), 3, "a sprawl is basic: everyone has one")
