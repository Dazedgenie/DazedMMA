extends GutTest
## More striking defence (docs/01 §44, D181): the shoulder roll, leaning back out of the way and
## the high guard. Like the slip, each has to be up as the strike lands, then it's one roll. A roll
## sets up a counter right hand and the overhand comes over it; a lean back can't be done on the
## fence and leaves him off balance for the next strike; a block on the high guard still lets a
## third in, and the uppercut and body shots get round it. The AI picks the defence with the best odds.

const SEED: int = 20261102
const SEEDS: int = 40
## A defender who wins nearly every defence, and a striker who can't hide anything.
const DEFENDER := { "striking_defense": 100, "boxing": 100, "footwork": 100, "speed": 100 }
const STRIKER := { "kicking": 0, "boxing": 0, "speed": 0, "power": 0 }

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart; Blue at `blue_x` (4.2 = his back on the fence).
func _pair(red_stats: Dictionary = STRIKER, blue_stats: Dictionary = DEFENDER, gap: float = 1.8, fight_seed: int = SEED, blue_x: float = 0.9) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(blue_x - gap, 0.0)
	sim.fighters[1].pos = Vector2(blue_x, 0.0)
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


## Red throws `strike` at tick 0 and Blue puts up `defense` at `up` (each one up as a cross lands at tick 3).
func _meet(strike: String, defense: String, up: int, fight_seed: int, blue_x: float = 0.9) -> FightSim:
	var sim: FightSim = _pair(STRIKER, DEFENDER, 1.8, fight_seed, blue_x)
	_queue(sim, 0, 0, strike)
	_queue(sim, up, 1, defense)
	return sim


# --- Who has what --------------------------------------------------------------------

func test_anyone_can_raise_a_high_guard_and_the_roll_and_lean_back_are_techniques() -> void:
	assert_true(_actions.get_action("high_guard").get("basic", false))
	assert_false(_actions.get_action("shoulder_roll").get("basic", false))
	assert_false(_actions.get_action("lean_back").get("basic", false))
	for id: String in ["boxer", "counter_striker"]:
		assert_has(_roster.profile(id).techniques, "shoulder_roll", id)
	for id: String in ["counter_striker", "kicker", "karate"]:
		assert_has(_roster.profile(id).techniques, "lean_back", id)
	for id: String in ["wrestler", "brawler", "muay_thai"]:
		assert_does_not_have(_roster.profile(id).techniques, "shoulder_roll", id)
		assert_does_not_have(_roster.profile(id).techniques, "lean_back", id)


# --- The shoulder roll ---------------------------------------------------------------

func test_a_rolled_punch_misses_and_sets_up_a_counter_right_hand() -> void:
	var rolled: int = 0
	for n in SEEDS:
		var sim: FightSim = _meet("cross", "shoulder_roll", 2, SEED + n)
		_ticks(sim, 4)
		var met: Array[FightEvent] = _events(sim, FightEvent.STRIKE_DEFENDED, 1)
		assert_eq(met.size(), 1, "the roll meets the cross once")
		if not met[0].data.worked:
			continue
		rolled += 1
		assert_eq(_events(sim, FightEvent.STRIKE_LANDED).size(), 0, "the cross misses")
		assert_has(_bonus_names(sim.odds_breakdown(1, "cross")), "off the roll")
		assert_has(_bonus_names(sim.odds_breakdown(1, "overhand")), "off the roll")
		assert_does_not_have(_bonus_names(sim.odds_breakdown(1, "hook")), "off the roll", "the right hand only")
		_ticks(sim, 600 / FightClock.TICK_MS + 1)
		assert_does_not_have(_bonus_names(sim.odds_breakdown(1, "cross")), "off the roll", "for a moment only")
	assert_gt(rolled, SEEDS * 4 / 5)


func test_the_overhand_comes_over_the_top_of_a_roll() -> void:
	var sim: FightSim = _pair(STRIKER, {})
	_queue(sim, 0, 0, "overhand")
	_ticks(sim, 1)
	var over: OddsBreakdown = sim.odds_breakdown(1, "shoulder_roll")
	assert_has(_bonus_names(over), "against the overhand")
	var straight: FightSim = _pair(STRIKER, {})
	_queue(straight, 0, 0, "cross")
	_ticks(straight, 1)
	var cross: OddsBreakdown = straight.odds_breakdown(1, "shoulder_roll")
	assert_does_not_have(_bonus_names(cross), "against the overhand")
	assert_lt(over.chance, cross.chance)


# --- Leaning back --------------------------------------------------------------------

func test_a_punch_he_leans_back_from_misses_but_the_next_strike_lands_more() -> void:
	var leaned: int = 0
	for n in SEEDS:
		var sim: FightSim = _meet("cross", "lean_back", 2, SEED + n)
		_ticks(sim, 4)
		var met: Array[FightEvent] = _events(sim, FightEvent.STRIKE_DEFENDED, 1)
		assert_eq(met.size(), 1, "the lean back meets the cross once")
		if not met[0].data.worked:
			continue
		leaned += 1
		assert_eq(_events(sim, FightEvent.STRIKE_LANDED).size(), 0, "the cross misses")
		assert_has(_bonus_names(sim.odds_breakdown(0, "hook")), "leaned back", "off balance")
		assert_does_not_have(_bonus_names(sim.odds_breakdown(1, "cross")), "leaned back", "it's his opponent's strikes that land more")
		_ticks(sim, 600 / FightClock.TICK_MS + 1)
		assert_does_not_have(_bonus_names(sim.odds_breakdown(0, "hook")), "leaned back", "for a moment only")
	assert_gt(leaned, SEEDS * 4 / 5)


func test_he_can_t_lean_back_with_his_back_on_the_fence() -> void:
	var sim: FightSim = _pair(STRIKER, DEFENDER, 1.8, SEED, 4.2)
	assert_has(sim.active_flags(1), "BACK_TO_CAGE")
	var b: OddsBreakdown = sim.odds_breakdown(1, "lean_back")
	assert_eq(b.chance, 0.0)
	assert_eq(b.missing, "own BACK_TO_CAGE")
	for n in 10:
		var on_fence: FightSim = _meet("cross", "lean_back", 2, SEED + n, 4.2)
		_ticks(on_fence, 4)
		var met: Array[FightEvent] = _events(on_fence, FightEvent.STRIKE_DEFENDED, 1)
		assert_eq(met.size(), 1)
		assert_false(met[0].data.worked, "nowhere to lean")
	assert_gt(_pair().odds_breakdown(1, "lean_back").chance, 0.5, "in the open he can")


# --- The high guard ------------------------------------------------------------------

func test_a_punch_on_the_high_guard_does_a_third_of_its_damage() -> void:
	var blocked: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "boxing": 100, "speed": 100, "power": 0 }, {}, 1.8, SEED + n)
		_queue(sim, 0, 0, "cross")
		_queue(sim, 1, 1, "high_guard")
		_ticks(sim, 4)
		var met: Array[FightEvent] = _events(sim, FightEvent.STRIKE_DEFENDED, 1)
		assert_eq(met.size(), 1, "the guard meets the cross once")
		if not met[0].data.worked:
			continue
		assert_true(met[0].data.get("blocked", false))
		var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
		if landed.is_empty():
			continue  # The cross missed anyway.
		blocked += 1
		assert_true(landed[0].data.get("blocked", false))
		assert_true(landed[0].data.get("covered", false), "a shot on the guard, like covering up")
		assert_eq(landed[0].data.damage, maxi(1, roundi(sim.strike_damage(sim.fighters[0], "cross") * 0.33)))
	assert_gt(blocked, SEEDS / 4)


func test_the_uppercut_and_body_shots_get_round_the_high_guard() -> void:
	var sim: FightSim = _pair()
	_queue(sim, 0, 1, "high_guard")
	_ticks(sim, 2)
	assert_has(sim.active_flags(1), "HIGH_GUARD")
	for strike: String in ["uppercut", "body_hook", "body_kick"]:
		assert_has(_bonus_names(sim.odds_breakdown(0, strike)), "HIGH_GUARD", strike)
	assert_does_not_have(_actions.get_action("high_guard").defense.against_strikes, "uppercut", "it comes up between the gloves")
	assert_does_not_have(_actions.get_action("high_guard").defense.against_strikes, "body_hook")


func test_a_shot_on_the_high_guard_doesn_t_count_toward_stopping_it() -> void:
	var on_guard: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "boxing": 100, "speed": 100, "power": 0 }, { "striking_defense": 100, "chin": 100 }, 1.8, SEED + n)
		sim.fighters[1].rocked_ticks = 100
		_queue(sim, 0, 0, "cross")
		_queue(sim, 1, 1, "high_guard")
		_ticks(sim, 4)
		var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
		if landed.is_empty() or not landed[0].data.get("blocked", false):
			continue
		on_guard += 1
		assert_eq(sim.fighters[1].unanswered, 0, "on the gloves: he's defending himself")
	assert_gt(on_guard, 3)


# --- The AI --------------------------------------------------------------------------

func test_the_ai_picks_the_defence_with_the_best_odds_and_fires_the_right_hand_off_the_roll() -> void:
	# A quick, hard puncher: the slip and the lean back (against his Boxing and Speed) and the high guard
	# (against his Power) are all worse than the roll for a man with Boxing 100.
	var puncher := FighterState.new("Puncher", { "boxing": 100, "speed": 100, "power": 100 }, ["cross"], 0.08, StyleLeanings.new({ "range": -100 }))
	var roller := FighterState.new("Roller", { "fight_iq": 100, "striking_defense": 100, "boxing": 100, "speed": 0, "footwork": 0 },
		["jab", "cross", "hook", "overhand", "slip", "shoulder_roll", "lean_back"], 0.0001)
	var sim := FightSim.new(SEED, [puncher, roller], _actions, 1, 300)
	_ticks(sim, 3000)
	var met: Array[FightEvent] = _events(sim, FightEvent.STRIKE_DEFENDED, 1)
	assert_gt(met.size(), 3)
	var rolls: int = met.filter(func(e: FightEvent) -> bool: return e.data.action_id == "shoulder_roll").size()
	assert_gt(rolls, met.size() / 2, "mostly the roll, his best")
	var off_roll: Array[Dictionary] = _starts(sim, 1).filter(func(s: Dictionary) -> bool: return s.why == "off the roll")
	assert_gt(off_roll.size(), 0, "a counter off the roll")


func test_a_puncher_follows_up_when_his_man_leans_back() -> void:
	var puncher := FighterState.new("Puncher", { "speed": 0 }, ["jab", "cross", "hook"], 0.08, StyleLeanings.new({ "range": -100 }))
	var leaner := FighterState.new("Leaner", { "fight_iq": 100, "striking_defense": 100, "footwork": 100, "speed": 100 }, ["jab", "lean_back"], 0.0001)
	var sim := FightSim.new(SEED, [puncher, leaner], _actions, 1, 300)
	_ticks(sim, 3000)
	var leans: Array[FightEvent] = _events(sim, FightEvent.STRIKE_DEFENDED, 1).filter(func(e: FightEvent) -> bool: return e.data.action_id == "lean_back" and e.data.worked)
	assert_gt(leans.size(), 2, "he leans back from some")
	assert_true(_starts(sim, 0).any(func(s: Dictionary) -> bool: return s.why == "he's leaning back"), "the next punch comes")
