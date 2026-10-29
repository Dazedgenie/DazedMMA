extends GutTest
## Liver shots (D143, docs/01 §35): a hard body shot can find the liver. He freezes, folds a
## moment later and goes down (a knockdown, his head clear), then gets up winded, hands low.

const SEED: int = 20261029
const SEEDS: int = 60

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart, under pro rules.
func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, gap: float = 1.2, fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions)
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


## Blue has just taken a liver shot from Red: it takes him next tick.
func _liver_coming(sim: FightSim) -> void:
	sim.fighters[1].liver_ticks = 1
	sim.fighters[1].liver_by = 0


func test_a_hard_body_shot_can_find_the_liver_and_he_folds_a_moment_later() -> void:
	var found: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "kicking": 100, "power": 100 }, { "durability": 0, "striking_defense": 0 }, 1.8, SEED + n)
		sim.fighters[1].damage.body = 40
		sim.submit(FightCommand.queue_action(0, 0, "body_kick"))
		_ticks(sim, 12)
		var liver: Array[FightEvent] = _events(sim, FightEvent.LIVER_SHOT, 1)
		if liver.is_empty():
			continue
		found += 1
		_ticks(sim, FightSim.LIVER_DELAY_TICKS)
		var down: Array[FightEvent] = _events(sim, FightEvent.KNOCKDOWN, 1)
		assert_eq(down.size(), 1, "seed %d" % (SEED + n))
		assert_true(down[0].data.liver)
		assert_between(down[0].tick - liver[0].tick, FightSim.LIVER_DELAY_TICKS - 1, FightSim.LIVER_DELAY_TICKS, "it takes him a moment later, not on the spot")
	assert_gt(found, 0, "a hard body kick on a hurt body finds the liver sometimes")


func test_the_liver_odds_grow_with_the_damage_and_the_body_damage_he_carries() -> void:
	var sim: FightSim = _pair({}, { "durability": 50 })
	var fresh: float = sim.body_shock(0, 12)
	assert_almost_eq(fresh, 12.0 / (FightSim.LIVER_THRESHOLD_BASE + FightSim.LIVER_THRESHOLD_PER_DURABILITY * 50), 0.0001)
	sim.fighters[1].damage.body = 40
	assert_gt(sim.body_shock(0, 12), fresh, "worse on a body that's already been hit")
	assert_eq(sim.liver_chance(0.5), 0.0, "a light one never does it")
	assert_eq(sim.liver_chance(10.0), FightSim.LIVER_MAX)


func test_folding_is_a_knockdown_with_his_head_clear() -> void:
	var sim: FightSim = _pair()
	_liver_coming(sim)
	sim.tick()
	var f: FighterState = sim.fighters[1]
	assert_true(f.is_down())
	assert_false(f.is_rocked(), "it's the body, not the head")
	assert_eq(f.knockdowns, 1)
	assert_has(sim.active_flags(1), "DOWN", "so he can be followed down (D142)")
	assert_lt(f.stamina, f.max_stamina() - FightSim.LIVER_STAMINA + 1.0, "it takes his wind")


func test_he_gets_up_winded_with_his_hands_low() -> void:
	var sim: FightSim = _pair()
	_liver_coming(sim)
	_ticks(sim, 1 + FightSim.LIVER_DOWN_TICKS)
	assert_false(sim.fighters[1].is_down())
	assert_has(sim.active_flags(1), "HANDS_LOW", "guarding the body")
	_ticks(sim, FightSim.LIVER_WINDED_TICKS + 1)
	assert_does_not_have(sim.active_flags(1), "HANDS_LOW", "and it passes")


func test_while_its_coming_he_is_frozen() -> void:
	var sim: FightSim = _pair()
	sim.fighters[1].liver_ticks = 3
	sim.fighters[1].liver_by = 0
	sim.submit(FightCommand.queue_action(0, 1, "jab"))
	_ticks(sim, 2)
	assert_eq(sim.fighters[1].action_id, "", "he can't start anything")
	assert_has(sim.active_flags(1), "HANDS_LOW")


func test_head_shots_and_ground_shots_never_find_the_liver() -> void:
	for n in SEEDS:
		var sim: FightSim = _pair({ "kicking": 100, "power": 100 }, { "durability": 0, "chin": 100, "striking_defense": 0 }, 1.8, SEED + n)
		sim.fighters[1].damage.body = 60
		sim.submit(FightCommand.queue_action(0, 0, "head_kick"))
		_ticks(sim, 12)
		assert_eq(_events(sim, FightEvent.LIVER_SHOT).size(), 0)
	var ground: FightSim = _pair({ "power": 100 }, { "durability": 0 }, 1.2, SEED, )
	ground.ruleset = Ruleset.load_id("amateur_adult")  # Ground punches go to the body there.
	assert_true(ground.apply_transition(0, "double_leg"))
	ground.fighters[1].damage.body = 60
	for n in 20:
		ground.submit(FightCommand.queue_action(ground.now, 0, "ground_punch"))
		_ticks(ground, 8)
	assert_eq(_events(ground, FightEvent.LIVER_SHOT).size(), 0, "lying on his back, there's nowhere to fold")


func test_dropped_while_its_coming_is_one_fall_not_two() -> void:
	var sim: FightSim = _pair()
	sim.fighters[1].liver_ticks = 3
	sim.fighters[1].liver_by = 0
	sim._knockdown(0, 0.0)
	_ticks(sim, FightSim.DOWN_TICKS + 10)
	assert_eq(sim.fighters[1].knockdowns, 1)
