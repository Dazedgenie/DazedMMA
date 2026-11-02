extends GutTest
## Striking defence (docs/01 §38, D180): checking a low kick, slipping a straight punch and
## covering up. A check or a slip has to be up as the strike lands, then it's one roll; a
## cover-up takes half the head damage and leaves the body open. The AI checks and slips what
## it reads, counters off the slip, and covers up when rocked (always on Survive!).

const SEED: int = 20261030
const SEEDS: int = 40
## A defender who wins nearly every check and slip, and a striker who can't hide anything.
const DEFENDER := { "striking_defense": 100, "kicking": 100, "speed": 100 }
const STRIKER := { "kicking": 0, "boxing": 0, "speed": 50 }

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart in the middle of the cage.
func _pair(red_stats: Dictionary = STRIKER, blue_stats: Dictionary = DEFENDER, gap: float = 1.8, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-gap / 2.0, 0.0)
	sim.fighters[1].pos = Vector2(gap / 2.0, 0.0)
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


## Telegraph events (a move starting) for one fighter: [{tick, action_id, why}].
func _starts(sim: FightSim, actor: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _events(sim, FightEvent.ACTION_PHASE, actor):
		if e.data.phase == "telegraph":
			out.append({ "tick": e.tick, "action_id": e.data.action_id, "why": String(e.data.get("why", "")) })
	return out


func _bonus_names(b: OddsBreakdown) -> Array[String]:
	var out: Array[String] = []
	for x: Dictionary in b.bonuses:
		out.append(x.name)
	return out


# --- Who has what --------------------------------------------------------------------

func test_anyone_can_check_a_kick_or_cover_up_and_slipping_is_a_boxing_technique() -> void:
	assert_true(_actions.get_action("check_kick").get("basic", false))
	assert_true(_actions.get_action("cover_up").get("basic", false))
	assert_false(_actions.get_action("slip").get("basic", false))
	for id: String in ["boxer", "counter_striker", "dirty_boxer", "muay_thai"]:
		assert_has(_roster.profile(id).techniques, "slip", id)
	for id: String in ["kicker", "wrestler", "brawler"]:
		assert_does_not_have(_roster.profile(id).techniques, "slip", id)


# --- Checking a kick -----------------------------------------------------------------

func test_a_check_up_as_the_low_kick_lands_stops_it_and_the_kicker_s_shin_pays() -> void:
	var checked: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair(STRIKER, DEFENDER, 1.8, SEED + n)
		_queue(sim, 0, 0, "leg_kick")
		_queue(sim, 2, 1, "check_kick")  # Up from tick 2, as the kick lands at tick 4.
		_ticks(sim, 5)
		var met: Array[FightEvent] = _events(sim, FightEvent.STRIKE_DEFENDED, 1)
		assert_eq(met.size(), 1, "the check meets the kick once")
		if not met[0].data.worked:
			continue
		checked += 1
		var kicker: FighterState = sim.fighters[0]
		var checker: FighterState = sim.fighters[1]
		var kick: float = sim.strike_damage(kicker, "leg_kick")
		var rear: int = 1 - kicker.lead_leg()
		assert_eq(_events(sim, FightEvent.STRIKE_LANDED).size(), 0, "the kick doesn't land")
		assert_eq(_events(sim, FightEvent.STRIKE_MISSED, 0)[0].data.reason, "defended")
		assert_eq(met[0].data.damage, roundi(kick * FightSim.CHECK_KICKER_SHARE), "60% of the kick goes back into his shin")
		assert_eq(kicker.leg_damage[rear], met[0].data.damage, "on his kicking leg, the back one")
		assert_eq(kicker.leg_damage[1 - rear], 0)
		assert_eq(checker.leg_damage[checker.lead_leg()], roundi(kick * FightSim.CHECK_SHIN_SHARE), "the checker takes a little")
		assert_has(sim.active_flags(0), "ONE_LEG", "and he's left on one leg a moment longer")
	assert_gt(checked, SEEDS * 4 / 5)


func test_a_good_kicker_hides_his_kicks_from_the_check() -> void:
	var average: FightSim = _pair({ "kicking": 50 }, {})
	var good: FightSim = _pair({ "kicking": 70 }, {})
	assert_does_not_have(_bonus_names(average.odds_breakdown(1, "check_kick")), "hidden")
	var b: OddsBreakdown = good.odds_breakdown(1, "check_kick")
	assert_has(_bonus_names(b), "hidden", "his Kicking above average counts again")
	assert_almost_eq(b.chance, 0.6 - 0.2 - 0.5 * 0.2, 0.001)


func test_a_check_too_early_is_spent_before_the_kick_arrives() -> void:
	var sim: FightSim = _pair()
	_queue(sim, 0, 1, "check_kick")
	_ticks(sim, 6)
	_queue(sim, sim.now, 0, "leg_kick")
	_ticks(sim, 6)
	assert_eq(_events(sim, FightEvent.STRIKE_DEFENDED).size(), 0)


func test_a_check_does_nothing_against_a_punch_or_a_body_kick() -> void:
	for strike: String in ["cross", "body_kick"]:
		var sim: FightSim = _pair()
		_queue(sim, 0, 0, strike)
		_queue(sim, 1, 1, "check_kick")
		_ticks(sim, 8)
		assert_eq(_events(sim, FightEvent.STRIKE_DEFENDED).size(), 0, strike)


# --- Slipping a punch ----------------------------------------------------------------

func test_a_slipped_punch_misses_and_his_counter_comes_off_the_slip() -> void:
	var slipped: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair(STRIKER, DEFENDER, 1.8, SEED + n)
		_queue(sim, 0, 0, "cross")
		_queue(sim, 2, 1, "slip")  # Up from tick 2, as the cross lands at tick 3.
		_ticks(sim, 4)
		var met: Array[FightEvent] = _events(sim, FightEvent.STRIKE_DEFENDED, 1)
		assert_eq(met.size(), 1, "the slip meets the cross once")
		if not met[0].data.worked:
			continue
		slipped += 1
		assert_eq(_events(sim, FightEvent.STRIKE_LANDED).size(), 0, "the cross misses")
		assert_has(_bonus_names(sim.odds_breakdown(1, "hook")), "off the slip")
		_ticks(sim, FightSim.SLIP_COUNTER_TICKS + 1)
		assert_does_not_have(_bonus_names(sim.odds_breakdown(1, "hook")), "off the slip", "for a moment only")
	assert_gt(slipped, SEEDS * 4 / 5)


func test_slipping_is_for_straight_punches_and_the_uppercut_punishes_it() -> void:
	for strike: String in ["hook", "uppercut", "leg_kick"]:
		var sim: FightSim = _pair(STRIKER, DEFENDER, 0.9)
		_queue(sim, 0, 0, strike)
		_queue(sim, 1, 1, "slip")
		_ticks(sim, 8)
		assert_eq(_events(sim, FightEvent.STRIKE_DEFENDED).size(), 0, strike)
	var sim: FightSim = _pair(STRIKER, DEFENDER, 0.9)
	_queue(sim, 0, 1, "slip")
	_ticks(sim, 1)
	assert_has(sim.active_flags(1), "SLIPPING")
	assert_has(_bonus_names(sim.odds_breakdown(0, "uppercut")), "SLIPPING")


# --- Covering up ---------------------------------------------------------------------

func test_through_the_guard_half_the_head_damage_gets_in_and_the_body_is_open() -> void:
	var covered: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "boxing": 100, "speed": 100 }, {}, 1.8, SEED + n)
		_queue(sim, 0, 1, "cover_up")
		_queue(sim, 2, 0, "cross")
		_ticks(sim, 6)
		assert_has(sim.active_flags(1), "COVERED")
		assert_has(_bonus_names(sim.odds_breakdown(0, "body_hook")), "COVERED", "elbows up, body open")
		var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
		if landed.is_empty():
			continue
		covered += 1
		assert_true(landed[0].data.get("covered", false))
		assert_eq(landed[0].data.damage, maxi(1, roundi(sim.strike_damage(sim.fighters[0], "cross") * 0.5)))
		assert_eq(sim.fighters[1].phase, "active", "a shot on the guard doesn't knock it down")
	assert_gt(covered, SEEDS / 2)


func test_a_rocked_man_covering_up_has_his_hands_up_and_the_referee_lets_it_go_on() -> void:
	var stopped_counts: Array[int] = []
	for cover: bool in [true, false]:
		var landed_once: bool = false
		for n in SEEDS:
			var sim: FightSim = _pair({ "boxing": 100, "speed": 100, "power": 0 }, { "chin": 100 }, 1.8, SEED + n)
			sim.fighters[1].rocked_ticks = 100
			if cover:
				_queue(sim, 0, 1, "cover_up")
			_queue(sim, 2, 0, "jab")
			_ticks(sim, 5)
			if cover:
				assert_does_not_have(sim.active_flags(1), "HANDS_LOW", "hurt, but his hands are up")
			if _events(sim, FightEvent.STRIKE_LANDED, 0).is_empty() or not sim.fighters[1].is_rocked():
				continue
			landed_once = true
			stopped_counts.append(sim.fighters[1].unanswered)
			break
		assert_true(landed_once)
	assert_eq(stopped_counts, [0, 1] as Array[int], "only clean shots count toward stopping it")


# --- The AI --------------------------------------------------------------------------

func test_a_fighter_checks_the_low_kicks_he_reads() -> void:
	var kicker := FighterState.new("Kicker", {}, ["leg_kick", "calf_kick"], 0.08, StyleLeanings.new({ "range": -100 }))
	var checker := FighterState.new("Checker", { "fight_iq": 100, "striking_defense": 100, "kicking": 100 }, ["jab"], 0.0001, StyleLeanings.new({ "range": -100 }))
	var sim := FightSim.new(SEED, [kicker, checker], _actions, 1, 300)
	_ticks(sim, 3000)
	var checks: Array[FightEvent] = _events(sim, FightEvent.STRIKE_DEFENDED, 1)
	assert_gt(checks.size(), 5, "he checks some of them")
	assert_true(_starts(sim, 1).any(func(s: Dictionary) -> bool: return s.why == "check the leg kick"))
	assert_true(checks.any(func(e: FightEvent) -> bool: return e.data.worked))


func test_only_a_fighter_who_knows_the_slip_slips_and_he_counters_off_it() -> void:
	var results: Array[int] = []
	for knows: bool in [true, false]:
		var moves: Array[String] = ["jab", "cross", "hook"]
		if knows:
			moves.append("slip")
		var puncher := FighterState.new("Puncher", {}, ["cross"], 0.08, StyleLeanings.new({ "range": -100 }))
		var slipper := FighterState.new("Slipper", { "fight_iq": 100, "striking_defense": 100, "speed": 100 }, moves, 0.0001)
		var sim := FightSim.new(SEED, [puncher, slipper], _actions, 1, 300)
		_ticks(sim, 3000)
		results.append(_events(sim, FightEvent.STRIKE_DEFENDED, 1).size())
		if knows:
			assert_true(_starts(sim, 1).any(func(s: Dictionary) -> bool: return s.why == "off the slip"), "a counter off the slip")
	assert_gt(results[0], 3)
	assert_eq(results[1], 0)


func test_a_rocked_fighter_covers_up_sometimes_and_always_on_survive() -> void:
	for survive: bool in [false, true]:
		var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions)
		sim.fighters[0].pos = Vector2(-0.9, 0.0)
		sim.fighters[1].pos = Vector2(0.9, 0.0)
		if survive:
			sim.submit(FightCommand.live_call(0, 1, "survive"))
			for k in 40:
				sim.tick()
				if not sim.decisions[1].calls.focus.is_empty():
					break
			assert_false(sim.decisions[1].calls.focus.is_empty(), "Survive! heard")
		sim.fighters[0].pos = Vector2(-0.9, 0.0)
		sim.fighters[1].pos = Vector2(0.9, 0.0)
		sim.fighters[0].clear_action()
		sim.fighters[1].clear_action()
		sim.fighters[1].rocked_ticks = 30
		sim.decisions[1].ai._cover_roll = 0.99  # Above the 40% an average fighter has on his own.
		var d: Decision = sim.decisions[1].ai.choose(sim.views[1], sim.decisions[1])
		if survive:
			assert_eq(d.action_id, "cover_up", "Survive! makes him")
			assert_eq(d.reason, "covers up")
		else:
			assert_ne(d.action_id, "cover_up", "not this time on his own")
		sim.decisions[1].ai._cover_roll = 0.1
		assert_eq(sim.decisions[1].ai.choose(sim.views[1], sim.decisions[1]).action_id, "cover_up", "under his own chance he does")
