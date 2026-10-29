extends GutTest
## Following a knockdown down to the ground (D142, docs/01 §34): the move that jumps on a
## knocked-down man, where it lands, what a miss does, the fighter AI and the Takedown! call.

const SEED: int = 20261029
const SEEDS: int = 40

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


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


## Knocks Blue down where he stands, as a knockdown does (FightSim._knockdown).
func _knock_down(sim: FightSim) -> void:
	sim.fighters[1].knockdowns += 1
	sim.fighters[1].down_ticks = FightSim.DOWN_TICKS
	sim.fighters[1].rocked_ticks = sim.rocked_duration(sim.fighters[1])


func test_following_him_down_needs_him_down() -> void:
	var sim: FightSim = _pair()
	assert_eq(sim.odds(0, "follow_down"), 0.0, "standing up, there's nobody to jump on")
	_knock_down(sim)
	assert_gt(sim.odds(0, "follow_down"), 0.5)
	assert_true(_actions.get_action("follow_down").get("basic", false), "everyone knows how")


func test_a_clean_follow_up_lands_on_top_in_half_guard_with_him_still_hurt() -> void:
	var landed: Dictionary = {}
	for n in SEEDS:
		var sim: FightSim = _pair({ "scrambles": 100, "top_control": 100 }, {}, 1.2, SEED + n)
		_knock_down(sim)
		assert_true(sim.submit(FightCommand.queue_action(0, 0, "follow_down")))
		_ticks(sim, 10)
		if sim.situation.is_standing():
			continue
		landed[sim.situation.position] = true
		assert_eq(sim.situation.role(0), PositionLibrary.TOP, "seed %d" % (SEED + n))
		assert_false(sim.fighters[1].is_down(), "he's on his back in a position now, not down")
		assert_true(sim.fighters[1].is_rocked(), "and still rocked: time for ground and pound")
	assert_has(landed, "half_guard", "a clean one lands past the legs")
	assert_eq(landed.keys().size() <= 2, true)


func test_a_scrappy_follow_up_lands_in_full_guard_and_a_miss_lets_him_up() -> void:
	var seen: Dictionary = {}
	for n in SEEDS:
		var sim: FightSim = _pair({ "scrambles": 0, "top_control": 0 }, { "scrambles": 100 }, 1.2, SEED + n)
		_knock_down(sim)
		sim.submit(FightCommand.queue_action(0, 0, "follow_down"))
		_ticks(sim, 10)
		if sim.situation.is_standing():
			assert_eq(_events(sim, FightEvent.GRAPPLE_STOPPED, 0)[0].data.reason, "defended", "seed %d" % (SEED + n))
			seen["missed"] = true
		else:
			seen[sim.situation.position] = true
	assert_has(seen, "full_guard")
	assert_has(seen, "missed")


func test_a_takedown_on_a_downed_man_still_finds_nobody_to_shoot_on() -> void:
	var sim: FightSim = _pair()
	_knock_down(sim)
	assert_true(sim.submit(FightCommand.queue_action(0, 0, "double_leg")))
	_ticks(sim, 6)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 0)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0].data.reason, "opponent down")


func test_the_ai_follows_a_knockdown_down_and_grapplers_more_often() -> void:
	var followed: Dictionary = { "wrestler": 0, "boxer": 0 }
	for red: String in followed:
		for n in SEEDS:
			var sim: FightSim = FightSim.new(SEED + n, _roster.make_pair(red, "kicker"), _actions)
			sim.fighters[0].pos = Vector2(-0.6, 0.0)
			sim.fighters[1].pos = Vector2(0.6, 0.0)
			_knock_down(sim)
			_ticks(sim, FightSim.DOWN_TICKS)
			for e in _events(sim, FightEvent.ACTION_PHASE, 0):
				if e.data.phase == "telegraph" and e.data.action_id == "follow_down":
					followed[red] += 1
					assert_eq(e.data.why, "while he's down")
	assert_gt(followed.boxer, 0, "even the Boxer jumps on him sometimes")
	assert_gt(followed.wrestler, followed.boxer, "the Wrestler more")


func test_the_takedown_call_follows_him_down_when_hes_down() -> void:
	var red := FighterState.new("Red", {}, ["double_leg"], 0.0)
	red.profile = { "personality": { "ego": -100 } }
	var sim := FightSim.new(SEED, [red, FighterState.new("Blue", {}, [], 0.0)], _actions)
	sim.fighters[0].pos = Vector2(-0.9, 0.0)
	sim.fighters[1].pos = Vector2(0.9, 0.0)
	_knock_down(sim)
	sim.submit(FightCommand.live_call(0, 0, "takedown"))
	_ticks(sim, 10)
	var started: Array = []
	for e in _events(sim, FightEvent.ACTION_PHASE, 0):
		if e.data.phase == "telegraph":
			started.append(e.data.action_id)
	assert_eq(started, ["follow_down"], "not a double-leg at a man on the floor")
