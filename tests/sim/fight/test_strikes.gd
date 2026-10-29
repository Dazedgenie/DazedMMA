extends GutTest
## The new strikes (D140, docs/01 §32): the uppercut, the overhand, the hook to the body,
## the calf kick, the elbow, and the short uppercut and short hook inside the clinch. What
## each one punishes, what it leaves open, where it reaches, the rules that ban elbows and
## the fighters who throw them.

const SEED: int = 20261029
const SEEDS: int = 40

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart in the middle of the cage.
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, gap: float = 1.2, fight_seed: int = SEED, rules: Ruleset = null) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, rules if rules != null else 1, 300)
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


## Each strike fighter i started in the fight, counted by id.
func _thrown(sim: FightSim, i: int) -> Dictionary:
	var out: Dictionary = {}
	for e in _events(sim, FightEvent.ACTION_PHASE, i):
		if e.data.phase == "telegraph" and sim.actions.get_action(e.data.action_id).category == "strike":
			out[e.data.action_id] = int(out.get(e.data.action_id, 0)) + 1
	return out


# --- What each one punishes -------------------------------------------------------

func test_each_new_strike_gets_its_bonus_on_the_opening_it_punishes() -> void:
	# [opponent's action, phase, flag it sets, the new strike, data bonus]
	var cases: Array = [
		["double_leg", "active", "HEAD_LOW", "uppercut", 0.25],
		["body_kick", "active", "ONE_LEG", "overhand", 0.10],
		["body_kick", "active", "ONE_LEG", "body_hook", 0.15],
		["hook", "active", "LEANING", "body_hook", 0.10],
	]
	for c: Array in cases:
		var sim: FightSim = _pair()
		var before: float = sim.odds(0, c[3])
		sim.fighters[1].action_id = c[0]
		sim.fighters[1].phase = c[1]  # active: not a counter window, so only the flag counts
		assert_has(sim.active_flags(1), c[2])
		assert_almost_eq(sim.odds(0, c[3]) - before, c[4], 0.0001, "%s against %s" % [c[3], c[2]])


func test_the_overhand_comes_over_hands_that_have_dropped() -> void:
	var sim: FightSim = _pair()
	sim.fighters[1].stamina = sim.fighters[1].max_stamina() * 0.2
	assert_has(sim.active_flags(1), "HANDS_LOW")
	var bonus: float = 0.0
	for b: Dictionary in sim.odds_breakdown(0, "overhand").to_dict().bonuses:
		if b.name == "HANDS_LOW":
			bonus = float(b.value)
	assert_almost_eq(bonus, 0.20, 0.0001, "on top of what tiredness takes off his defense")


func test_the_uppercut_drops_the_throwers_hands_for_the_overhand() -> void:
	var sim: FightSim = _pair()
	sim.fighters[0].action_id = "uppercut"
	sim.fighters[0].phase = "windup"
	assert_has(sim.active_flags(0), "HANDS_LOW", "the rear hand leaves his chin to come up the middle")
	sim.fighters[0].phase = "recovery"
	assert_does_not_have(sim.active_flags(0), "HANDS_LOW", "and it's back by the recovery")


func test_the_overhand_leaves_the_thrower_leaning_for_the_counter_hook() -> void:
	var sim: FightSim = _pair()
	var before: float = sim.odds(1, "hook")
	sim.fighters[0].action_id = "overhand"
	sim.fighters[0].phase = "active"
	assert_has(sim.active_flags(0), "LEANING", "he's over his front foot behind it")
	assert_almost_eq(sim.odds(1, "hook") - before, 0.15, 0.0001, "hook.json: +15% on a lean")


func test_an_uppercut_into_the_shot_stops_it_and_lands_harder() -> void:
	var landed_into: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({}, { "boxing": 100, "power": 100 }, 1.2, SEED + n)
		assert_true(sim.submit(FightCommand.queue_action(0, 0, "double_leg")))
		assert_true(sim.submit(FightCommand.queue_action(2, 1, "uppercut")))
		_ticks(sim, 8)
		var landed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 1)
		if landed.is_empty():
			continue
		landed_into += 1
		assert_eq(landed[0].data.into, "double_leg")
		assert_eq(landed[0].data.damage, roundi(7 * 1.5 * 1.4), "base 7 × Power 100 × 1.4 into the lowered head")
		assert_eq(_events(sim, FightEvent.GRAPPLE_STOPPED, 0)[0].data.by_action, "uppercut")
		assert_true(sim.situation.is_standing(), "the shot never got there")
	assert_gt(landed_into, 0, "it landed in some of the %d fights" % SEEDS)


func test_the_elbow_is_better_on_a_head_pulled_down_and_worse_with_your_own() -> void:
	var sim: FightSim = _pair()
	var neutral: float = sim.odds(0, "elbow")
	sim.fighters[1].tied_up_ticks = 10
	assert_has(sim.active_flags(1), "POSTURE_BROKEN")
	assert_almost_eq(sim.odds(0, "elbow") - neutral, 0.15, 0.0001, "his head is pulled down")
	sim.fighters[1].tied_up_ticks = 0
	sim.fighters[0].tied_up_ticks = 10
	assert_almost_eq(sim.odds(0, "elbow") - neutral, -0.15, 0.0001, "his own head is pulled down")


# --- Where they reach and what they hit ---------------------------------------------

func test_the_calf_kick_goes_to_the_legs_and_still_reaches_in_the_pocket() -> void:
	var calf: Dictionary = _actions.get_action("calf_kick")
	assert_eq(String(calf.strike.target), "legs")
	assert_has(calf.ranges, "pocket", "short enough to throw up close")
	assert_does_not_have(_actions.get_action("leg_kick").ranges, "pocket", "where the leg kick is too long")
	assert_lt(int(calf.phases_ms.telegraph), int(_actions.get_action("leg_kick").phases_ms.telegraph), "and quicker to come")
	var sim: FightSim = _pair({ "kicking": 100 }, { "striking_defense": 0 }, 1.2)
	assert_true(sim.submit(FightCommand.queue_action(0, 0, "calf_kick")))
	_ticks(sim, 10)
	var rolled: Array[FightEvent] = _events(sim, FightEvent.STRIKE_LANDED, 0)
	rolled.append_array(_events(sim, FightEvent.STRIKE_MISSED, 0))
	assert_eq(rolled.size(), 1)
	assert_false(rolled[0].data.has("reason"), "it reached: rolled on its odds, didn't fall short")


func test_the_uppercut_and_the_body_hook_only_reach_in_the_pocket() -> void:
	for id in ["uppercut", "body_hook"]:
		var sim: FightSim = _pair({}, {}, 1.8)
		assert_true(sim.submit(FightCommand.queue_action(0, 0, id)))
		_ticks(sim, 10)
		var missed: Array[FightEvent] = _events(sim, FightEvent.STRIKE_MISSED, 0)
		assert_eq(missed.size(), 1)
		assert_eq(missed[0].data.get("reason", ""), "out of range", "%s from mid range falls short" % id)


func test_the_body_hook_goes_to_the_body() -> void:
	assert_eq(String(_actions.get_action("body_hook").strike.target), "body")


# --- The rules -------------------------------------------------------------------

func test_elbows_are_refused_where_the_rules_ban_them() -> void:
	for id in ["amateur_adult", "amateur_teen"]:
		var sim: FightSim = _pair({}, {}, 1.2, SEED, Ruleset.load_id(id))
		sim.submit(FightCommand.queue_action(0, 0, "elbow"))
		sim.tick()
		assert_eq(sim.events[0].type, FightEvent.COMMAND_REJECTED, id)
	var pro: FightSim = _pair()
	assert_true(pro.submit(FightCommand.queue_action(0, 0, "elbow")))
	pro.tick()
	assert_eq(pro.fighters[0].action_id, "elbow", "pro rules allow them")


func test_the_muay_thai_fighter_throws_no_elbows_in_an_amateur_fight() -> void:
	for n in 3:
		var sim := FightSim.new(SEED + n, _roster.make_pair("muay_thai", "boxer"), _actions, Ruleset.load_id("amateur_adult"))
		sim.run_to_end()
		assert_false(_thrown(sim, 0).has("elbow"), "seed %d" % (SEED + n))


# --- The fighters ------------------------------------------------------------------

func test_each_fighter_throws_the_new_strikes_in_their_profile() -> void:
	# [red, blue, strikes red throws over three fights]
	var cases: Array = [
		["boxer", "kicker", ["uppercut", "overhand", "body_hook"]],
		["kicker", "boxer", ["calf_kick"]],
		["muay_thai", "boxer", ["elbow"]],
		["wrestler", "boxer", ["overhand"]],
		["boxer", "muay_thai", ["short_uppercut", "short_hook"]],
	]
	for c: Array in cases:
		var seen: Dictionary = {}
		for n in 3:
			var sim := FightSim.new(SEED + n, _roster.make_pair(c[0], c[1]), _actions)
			sim.run_to_end()
			seen.merge(_thrown(sim, 0))
		for id: String in c[2]:
			assert_has(seen, id, "%s throws the %s" % [c[0], id])


func test_the_muay_thai_fighter_elbows_in_the_clinch() -> void:
	var in_clinch: int = 0
	for n in 3:
		var sim := FightSim.new(SEED + n, _roster.make_pair("muay_thai", "wrestler"), _actions)
		var was_clinch: bool = false
		while not sim.is_over():
			if sim.situation.position == PositionLibrary.CLINCH and sim.fighters[0].action_id == "elbow" and sim.fighters[0].phase == "telegraph":
				if not was_clinch:
					in_clinch += 1
				was_clinch = true
			else:
				was_clinch = false
			sim.tick()
	assert_gt(in_clinch, 0, "elbows inside the clinch, not just from the pocket")


func test_the_short_uppercut_and_hook_are_only_thrown_inside_the_clinch() -> void:
	for id in ["short_uppercut", "short_hook"]:
		var action: Dictionary = _actions.get_action(id)
		assert_eq(action.positions, ["clinch"], id)
		var apart: FightSim = _pair()
		apart.submit(FightCommand.queue_action(0, 0, id))
		apart.tick()
		assert_eq(apart.events[0].type, FightEvent.COMMAND_REJECTED, "%s isn't thrown standing apart" % id)
	var sim: FightSim = _pair()
	sim.fighters[1].tied_up_ticks = 10
	var neutral: float = _pair().odds(0, "short_uppercut")
	assert_almost_eq(sim.odds(0, "short_uppercut") - neutral, 0.15, 0.0001, "up the middle into a head pulled down")


func test_the_boxer_fights_in_the_clinch_but_never_goes_looking_for_it() -> void:
	for n in 3:
		var sim := FightSim.new(SEED + n, _roster.make_pair("boxer", "muay_thai"), _actions)
		sim.run_to_end()
		for e in _events(sim, FightEvent.ACTION_PHASE, 0):
			assert_ne(e.data.action_id, "clinch_entry", "seed %d: his clinch_entry tendency is 0" % (SEED + n))
