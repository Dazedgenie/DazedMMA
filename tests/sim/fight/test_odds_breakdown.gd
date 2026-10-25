extends GutTest
## OddsBreakdown: every strike says where its odds came from (docs/12 §3 item 3, A16).

const SEED: int = 20261024

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _sim(red: FighterState, blue: FighterState) -> FightSim:
	var sim := FightSim.new(SEED, [red, blue], _actions)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	return sim


func test_the_parts_add_up_to_the_chance() -> void:
	var sim: FightSim = _sim(FighterState.new("Red", { "boxing": 70, "speed": 60 }, []), FighterState.new("Blue", {}, []))
	var b: OddsBreakdown = sim.odds_breakdown(0, "jab")
	assert_eq(b.base, 0.5)
	assert_almost_eq(b.stat_gap(), 0.15, 0.0001)
	assert_eq(b.bonuses.size(), 0)
	assert_almost_eq(b.chance, sim.odds(0, "jab"), 0.0001)


func test_a_catch_kick_names_the_opening_and_the_counter() -> void:
	var sim: FightSim = _sim(FighterState.new("Red", {}, []), FighterState.new("Blue", {}, []))
	assert_eq(sim.odds_breakdown(0, "catch_kick_single").missing, "ONE_LEG", "no kick, no catch")
	sim.fighters[1].action_id = "body_kick"
	sim.fighters[1].phase = "windup"
	var b: OddsBreakdown = sim.odds_breakdown(0, "catch_kick_single")
	assert_eq(b.missing, "")
	assert_eq(b.bonuses, [{ "name": "counter", "value": FightSim.COUNTER_BONUS }, { "name": "ONE_LEG", "value": 0.15 }] as Array[Dictionary])


func test_the_clamp_is_flagged_when_it_cuts_the_odds() -> void:
	var sim: FightSim = _sim(FighterState.new("Red", { "boxing": 100, "speed": 100 }, []), FighterState.new("Blue", { "striking_defense": 0 }, []))
	var d: Dictionary = sim.odds_breakdown(0, "jab").to_dict()
	assert_eq(d.chance, Contest.MAX_CHANCE)
	assert_true(d.get("clamped", false))


func test_strike_events_carry_the_breakdown_they_were_rolled_at() -> void:
	var sim: FightSim = _sim(FighterState.new("Red", { "boxing": 60 }, []), FighterState.new("Blue", {}, []))
	sim.submit(FightCommand.queue_action(0, 0, "jab"))
	for n in 10:
		sim.tick()
	var rolled: int = 0
	for e in sim.events:
		if e.type in [FightEvent.STRIKE_LANDED, FightEvent.STRIKE_MISSED]:
			rolled += 1
			assert_almost_eq(e.data.odds.chance, e.data.chance, 0.0001)
			assert_almost_eq(e.data.odds.stat_gap, 0.05, 0.0001)
	assert_eq(rolled, 1)
