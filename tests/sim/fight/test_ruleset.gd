extends GutTest
## Ruleset: the fight runs under rules loaded from data/rulesets (docs/08, docs/09 ruleset@1).

const SEED: int = 20261024

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _idle() -> Array[FighterState]:
	return [FighterState.new("Red", {}, []), FighterState.new("Blue", {}, [])]


func test_a_fight_defaults_to_pro_rules() -> void:
	var sim := FightSim.new(SEED, _idle(), _actions)
	assert_eq(sim.ruleset.id, "pro")
	assert_eq(sim.clock.rounds, 3)
	assert_eq(sim.clock.round_seconds, 300)


func test_the_fight_takes_its_rounds_from_the_ruleset() -> void:
	var sim := FightSim.new(SEED, _idle(), _actions, Ruleset.load_id("amateur_teen"))
	sim.run_to_end()
	assert_eq(sim.now, 3 * 120 * FightClock.TICKS_PER_SECOND, "teen amateurs fight three 2-minute rounds")


func test_protective_gear_scales_damage_down() -> void:
	var landed: Array[int] = []
	for id in ["pro", "amateur_teen"]:
		var sim := FightSim.new(SEED, [FighterState.new("Red", { "boxing": 100 }, []), FighterState.new("Blue", { "striking_defense": 0 }, [])],
			_actions, Ruleset.load_id(id))
		sim.fighters[0].pos = Vector2(-0.9, 0.0)
		sim.fighters[1].pos = Vector2(0.9, 0.0)
		sim.submit(FightCommand.queue_action(0, 0, "cross"))
		for n in 20:
			sim.tick()
		for e in sim.events:
			if e.type == FightEvent.STRIKE_LANDED:
				landed.append(e.data.damage)
	assert_eq(landed.size(), 2, "a 95% cross lands in both fights with this seed")
	assert_eq(landed[1], roundi(landed[0] * 0.6), "amateur_teen.json: damage × 0.6")


func test_an_action_the_rules_ban_is_refused() -> void:
	var kickboxing := Ruleset.load_id("pro")
	kickboxing.allows.takedowns = false
	var sim := FightSim.new(SEED, _idle(), _actions, kickboxing)
	sim.submit(FightCommand.queue_action(0, 0, "double_leg"))
	sim.tick()
	assert_eq(sim.events[0].type, FightEvent.COMMAND_REJECTED)
	assert_eq(sim.events[0].data.reason, "not allowed under Professional MMA rules")


func test_the_ai_never_picks_a_banned_action() -> void:
	var kickboxing := Ruleset.load_id("pro")
	kickboxing.allows.takedowns = false
	var repertoire: Array[String] = ["double_leg", "jab"]
	var sim := FightSim.new(SEED, [FighterState.new("Red", {}, repertoire, 0.1), FighterState.new("Blue", {}, [])], _actions, kickboxing)
	sim.run_to_end()
	for e in sim.events:
		assert_ne(e.data.get("action_id", ""), "double_leg")
