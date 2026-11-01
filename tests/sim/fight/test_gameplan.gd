extends GutTest
## Gameplan (D320–D324, docs/01 §42): the corner's plan built from an approach, a target and
## where to fight, set before the fight and at round breaks, followed less when it goes badly.

const SEED: int = 20261101

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim() -> FightSim:
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, ["jab", "leg_kick", "double_leg"], 0.3), FighterState.new("Blue", {}, [], 0.0)], _actions)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func test_every_part_of_a_plan_has_options_in_data() -> void:
	assert_eq(Gameplan.options(Gameplan.APPROACH).map(func(o: Array) -> String: return o[0]), ["pressure", "counter", "range", "conserve"])
	assert_eq(Gameplan.options(Gameplan.TARGET).map(func(o: Array) -> String: return o[0]), ["head", "body", "legs"])
	assert_eq(Gameplan.options(Gameplan.WHERE).map(func(o: Array) -> String: return o[0]), ["keep_standing", "clinch_work", "wrestle_heavy"])


func test_a_plan_built_from_three_parts_adds_the_leanings_and_multiplies_the_weights() -> void:
	var plan := Gameplan.compose({ "approach": "pressure", "target": "legs", "where": "wrestle_heavy" })
	assert_eq(plan.leanings, { "pace": 40.0, "range": 30.0, "base": 60.0 })
	assert_eq(plan.bias, { "takedown": 1.5 })
	assert_eq(plan.label, "Pressure · Legs · Take him down")
	assert_eq(Gameplan.describe({}), "Own game")
	assert_true(Gameplan.compose({}).is_empty())


func test_a_target_plan_only_moves_strikes_that_land_there() -> void:
	var view := FightView.new(_sim(), 0)
	var plan := Gameplan.compose({ "target": "legs" })
	assert_almost_eq(plan.adjust_weight(view, _actions.get_action("leg_kick"), 1.0), pow(2.0, Gameplan.STRENGTH), 1e-9, "half strength (D322): ×2 pulls as ×1.41")
	assert_almost_eq(plan.adjust_weight(view, _actions.get_action("jab"), 1.0), pow(0.75, Gameplan.STRENGTH), 1e-9)
	assert_eq(plan.adjust_weight(view, _actions.get_action("double_leg"), 1.0), 1.0, "not a strike")


func test_a_plan_never_pushes_a_leaning_past_70_or_pulls_one_back_from_past_it() -> void:
	var view := FightView.new(_sim(), 0)
	var plan := Gameplan.compose({ "approach": "range" })
	assert_eq(plan.adjust_leaning(view, StyleLeanings.RANGE, 0.0), -35.0 * Gameplan.STRENGTH)
	assert_eq(plan.adjust_leaning(view, StyleLeanings.RANGE, -60.0), -70.0, "a Kicker on the Range plan stops at −70")
	assert_eq(plan.adjust_leaning(view, StyleLeanings.RANGE, -90.0), -90.0, "already further out: left where he is")
	assert_eq(plan.adjust_leaning(view, StyleLeanings.PACE, 10.0), 10.0, "a leaning the plan doesn't name")


func test_the_corner_sets_the_plan_before_a_round_and_not_during_one() -> void:
	var sim: FightSim = _sim()
	assert_true(sim.submit(FightCommand.set_gameplan(0, 0, { "approach": "pressure" })))
	sim.tick()
	assert_eq(sim.decisions[0].gameplan.label, "Pressure")
	assert_eq(sim.decisions[0].leaning(sim.views[0], StyleLeanings.PACE), 40.0 * Gameplan.STRENGTH)
	sim.submit(FightCommand.set_gameplan(sim.now, 0, { "approach": "counter" }))
	sim.tick()
	assert_eq(sim.decisions[0].gameplan.label, "Pressure", "mid-round: refused")
	var rejected: Array = sim.events.filter(func(e: FightEvent) -> bool: return e.type == FightEvent.COMMAND_REJECTED)
	assert_eq(String(rejected[-1].data.reason), "gameplans are set before a round")


func test_a_new_plan_replaces_the_old_one() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_gameplan(0, 0, { "approach": "pressure", "where": "wrestle_heavy" }))
	sim.submit(FightCommand.set_gameplan(0, 0, { "target": "body" }))
	sim.tick()
	assert_eq(sim.decisions[0].gameplan.label, "Body")
	assert_eq(sim.decisions[0].leaning(sim.views[0], StyleLeanings.BASE), 0.0)
	assert_eq(sim.decisions[0].sources.filter(func(s: DecisionSource) -> bool: return s is Gameplan).size(), 1)


func test_a_plan_with_a_part_in_the_wrong_place_is_refused() -> void:
	assert_eq(Gameplan.check({ "approach": "legs" }), "'legs' isn't a approach")
	assert_eq(Gameplan.check({ "where": "nowhere" }), "no gameplan 'nowhere'")
	assert_eq(Gameplan.check({ "approach": "pressure", "target": "", "where": "clinch_work" }), "")


func test_a_fight_with_plans_replays_from_its_command_log() -> void:
	var sim := FightSim.new(SEED, _roster.make_pair("kicker", "boxer"), _actions, 1, 120)
	sim.submit(FightCommand.set_gameplan(0, 0, { "approach": "counter", "target": "legs" }))
	sim.submit(FightCommand.set_gameplan(0, 1, { "approach": "pressure", "where": "keep_standing" }))
	sim.run_to_end()
	var again: FightSim = FightSim.replay(SEED, _roster.make_pair("kicker", "boxer"), _actions, sim.command_log_as_dicts(), 1, 120)
	assert_eq(JSON.stringify(again.events_as_dicts()), JSON.stringify(sim.events_as_dicts()))


func test_the_legs_plan_sends_more_of_his_strikes_low() -> void:
	assert_gt(_low_share({ "target": "legs" }), _low_share({}) + 0.03, "a bigger share of low kicks over four fights")
	assert_lt(_low_share({ "target": "head" }), _low_share({}) - 0.03, "and fewer on the Head plan")


## The share of the Kicker's strikes against the Boxer aimed at the legs, over four one-round fights.
func _low_share(plan: Dictionary) -> float:
	var low: int = 0
	var all: int = 0
	for n in 4:
		var sim := FightSim.new(100 + n, _roster.make_pair("kicker", "boxer"), _actions, 1, 300)
		if not plan.is_empty():
			sim.submit(FightCommand.set_gameplan(0, 0, plan))
		sim.run_to_end()
		for e in sim.events:
			if e.actor == 0 and (e.type == FightEvent.STRIKE_LANDED or e.type == FightEvent.STRIKE_MISSED):
				all += 1
				if String(e.data.get("target", "")) == "legs":
					low += 1
	return float(low) / float(maxi(1, all))


func test_hurt_and_losing_a_fighter_keeps_less_of_the_plan_the_lower_his_fight_iq_and_the_bigger_his_ego() -> void:
	var sharp := FighterState.new("Sharp", { "fight_iq": 90 }, [], 0.0)
	var wild := FighterState.new("Wild", { "fight_iq": 30 }, [], 0.0)
	wild.profile = { "personality": { "ego": 80 } }
	assert_almost_eq(Gameplan.holds_it(sharp), 0.89, 0.001)
	assert_almost_eq(Gameplan.holds_it(wild), 0.29, 0.001)
	assert_gt(Gameplan.holds_it(wild, 100.0), Gameplan.holds_it(wild, 0.0), "trust in the corner holds him to it")
	var opp := FighterState.new("Opp", {}, [], 0.0)
	assert_false(Gameplan.under_pressure(wild, opp), "fresh and even: he sticks to it")
	opp.strikes_landed = 20
	wild.strikes_landed = 5
	assert_true(Gameplan.under_pressure(wild, opp), "taking four times what he lands")


func test_under_pressure_the_plan_pulls_less() -> void:
	var sim: FightSim = _sim()
	sim.submit(FightCommand.set_gameplan(0, 0, { "approach": "pressure" }))
	sim.tick()
	var view: FightView = sim.views[0]
	var plan: Gameplan = sim.decisions[0].gameplan
	assert_eq(plan.adjust_leaning(view, StyleLeanings.PACE, 0.0), 40.0 * Gameplan.STRENGTH)
	sim.fighters[0].rocked_ticks = 50
	sim.tick()
	var kept: float = Gameplan.holds_it(sim.fighters[0])
	assert_lt(kept, 1.0)
	assert_almost_eq(plan.adjust_leaning(sim.views[0], StyleLeanings.PACE, 0.0), 40.0 * Gameplan.STRENGTH * kept, 0.001)
	assert_string_contains(FightHud.plan_line(plan), "drifting off the plan")
