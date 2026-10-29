extends GutTest
## Flash knockdowns (D145, docs/01 §37): one big clean head shot can drop a man who wasn't rocked.

const SEED: int = 20261029
const SEEDS: int = 60

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _pair(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, gap: float = 1.8, fight_seed: int = SEED) -> FightSim:
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


func test_only_a_big_shot_can_flash_a_man_down() -> void:
	var sim: FightSim = _pair()
	assert_eq(sim.flash_chance(FightSim.FLASH_FROM), 0.0)
	assert_gt(sim.flash_chance(FightSim.FLASH_FROM + 0.5), 0.0)
	assert_eq(sim.flash_chance(100.0), FightSim.FLASH_MAX)


func test_a_jab_never_drops_a_fresh_man() -> void:
	var sim: FightSim = _pair({ "power": 100 }, { "chin": 0 })
	var dealt: float = sim.strike_damage(sim.fighters[0], "jab") * FightSim.COUNTER_DAMAGE
	assert_eq(sim.flash_chance(sim.head_shock(0, dealt)), 0.0, "even countering with all the power there is")


func test_a_big_head_kick_can_drop_a_fresh_man_with_one_shot() -> void:
	var flashed: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "kicking": 100, "power": 100 }, { "chin": 0, "striking_defense": 0 }, 1.8, SEED + n)
		sim.submit(FightCommand.queue_action(0, 0, "head_kick"))
		_ticks(sim, 12)
		var down: Array[FightEvent] = _events(sim, FightEvent.KNOCKDOWN, 1)
		if down.is_empty():
			continue
		if down[0].data.get("flash", false):
			flashed += 1
			assert_eq(_events(sim, FightEvent.ROCKED, 1).size(), 0, "seed %d: straight down, not rocked first" % (SEED + n))
			assert_true(sim.fighters[1].is_down() or sim.is_over())
	assert_gt(flashed, 0)


func test_on_the_ground_a_big_shot_rocks_but_there_is_nowhere_to_fall() -> void:
	for n in SEEDS:
		var sim: FightSim = _pair({ "power": 100, "top_control": 100 }, { "chin": 0, "guard": 0 }, 1.2, SEED + n)
		assert_true(sim.apply_transition(0, "double_leg"))
		sim.submit(FightCommand.queue_action(0, 0, "ground_elbow"))
		_ticks(sim, 8)
		assert_eq(_events(sim, FightEvent.KNOCKDOWN).size(), 0, "seed %d" % (SEED + n))
