extends GutTest
## A leg giving out (D144, docs/01 §36): the two legs tracked apart, low kicks landing on the front
## one, switching stance to hide it, a badly hurt leg buckling (a knockdown, head clear) and the limp.

const SEED: int = 20261029
const SEEDS: int = 60

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, `gap` metres apart, under pro rules.
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


## Red lands one leg kick (or tries: up to 10 ticks).
func _kick(sim: FightSim, id: String = "leg_kick") -> void:
	sim.submit(FightCommand.queue_action(sim.now, 0, id))
	_ticks(sim, 10)


func test_a_low_kick_lands_on_the_front_leg() -> void:
	var sim: FightSim = _pair({ "kicking": 100 }, { "striking_defense": 0 })
	for n in 6:
		_kick(sim)
	var f: FighterState = sim.fighters[1]
	assert_gt(f.leg_damage[FighterState.LEFT_LEG], 0, "an orthodox fighter's left leg is in front")
	assert_eq(f.leg_damage[FighterState.RIGHT_LEG], 0)
	assert_eq(f.damage.legs, f.leg_damage[0] + f.leg_damage[1], "the legs area is the two together")
	var southpaw := FighterState.new("South", {}, [], 0.0)
	southpaw.profile = { "stance": "southpaw" }
	assert_eq(southpaw.lead_leg(), FighterState.RIGHT_LEG)
	southpaw.switched = true
	assert_eq(southpaw.lead_leg(), FighterState.LEFT_LEG, "switched: the other one's in front")


func test_one_leg_kicked_to_pieces_is_a_leg_gone_while_the_other_is_fresh() -> void:
	var f := FighterState.new("Blue", { "durability": 50 }, [], 0.0)
	f.leg_damage = [300, 0]
	f.damage.legs = 300
	assert_almost_eq(f.leg_hurt(FighterState.LEFT_LEG), 1.0, 0.0001)
	assert_eq(f.leg_hurt(FighterState.RIGHT_LEG), 0.0)
	assert_lt(f.hurt("legs"), 0.5, "the legs as a whole are less than half gone")


func test_a_hurt_front_leg_makes_him_switch_stance_to_hide_it() -> void:
	var sim: FightSim = _pair({ "kicking": 100 }, { "striking_defense": 0, "durability": 50 })
	var f: FighterState = sim.fighters[1]
	f.leg_damage = [200, 0]
	f.damage.legs = 200
	var tries: int = 0
	while _events(sim, FightEvent.STANCE_SWITCHED, 1).is_empty() and tries < 10:
		_kick(sim)
		tries += 1
	assert_eq(_events(sim, FightEvent.STANCE_SWITCHED, 1).size(), 1)
	assert_true(f.switched)
	assert_eq(f.lead_leg(), FighterState.RIGHT_LEG, "the fresh leg goes in front")


func test_a_badly_hurt_leg_can_buckle_and_then_he_limps() -> void:
	var buckled: int = 0
	for n in SEEDS:
		var sim: FightSim = _pair({ "kicking": 100, "power": 100 }, { "striking_defense": 0, "durability": 0 }, 1.8, SEED + n)
		var f: FighterState = sim.fighters[1]
		f.leg_damage = [140, 140]  # Both legs gone: no switching away from it.
		f.damage.legs = 280
		_kick(sim)
		var down: Array[FightEvent] = _events(sim, FightEvent.KNOCKDOWN, 1)
		if down.is_empty():
			continue
		buckled += 1
		assert_eq(int(down[0].data.leg), FighterState.LEFT_LEG)
		assert_true(f.is_down())
		assert_false(f.is_rocked(), "the leg, not the head")
		assert_eq(f.limping, FighterState.LEFT_LEG)
		assert_lt(f.effective_stat("takedown_defense"), f.stat("takedown_defense") * (1.0 - FighterState.LIMP_PENALTY) + 0.01, "easier to take down")
		assert_has(f.condition_reasons("speed"), "limping")
	assert_gt(buckled, 0, "a hard leg kick on a gone leg buckles it sometimes")


func test_a_leg_that_isnt_hurt_never_buckles() -> void:
	var sim: FightSim = _pair()
	assert_eq(sim.buckle_chance(0.2, 12.0), 0.0)
	assert_gt(sim.buckle_chance(0.8, 12.0), 0.0)
	assert_eq(sim.buckle_chance(1.0, 1000.0), FightSim.BUCKLE_MAX)


func test_the_body_figure_shows_each_leg() -> void:
	var f := FighterState.new("Blue", {}, [], 0.0)
	f.leg_damage = [240, 0]
	f.damage.legs = 240
	var figure := BodyDamageFigure.new()
	figure.show_fighter(f)
	assert_gt(figure.leg_hurt[FighterState.LEFT_LEG], 0.5)
	assert_eq(figure.leg_hurt[FighterState.RIGHT_LEG], 0.0)
	assert_ne(figure.leg_colour(FighterState.LEFT_LEG), figure.leg_colour(FighterState.RIGHT_LEG))
	figure.free()
