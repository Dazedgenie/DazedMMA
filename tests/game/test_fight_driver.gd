extends GutTest
## FightDriver: plays a fight in real time at the chosen speed (#19, docs/06 §3, D50–D53, D91).

const SEED: int = 20261025
const FRAME: float = 0.05

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## The playtest matchup with the AI corner calling for blue, and some calls and a rule for red.
func _sim(fight_seed: int = SEED) -> FightSim:
	var sim := FightSim.new(fight_seed, _roster.make_pair("wrestler", "kicker"), _actions)
	sim.corners[1] = Corner.new(Corner.AI, fight_seed)
	sim.submit(FightCommand.set_rule(0, 0, 1, "catch_kick_and_shoot", 80.0))
	for t in [120, 900, 2500, 3400, 5100, 7777, 8800]:
		sim.submit(FightCommand.live_call(t, 0, "takedown"))
	sim.submit(FightCommand.live_call(1500, 0, "catch_the_kick"))
	sim.submit(FightCommand.live_call(6200, 0, "pressure"))
	return sim


func _ticks_in(driver: FightDriver, seconds: float) -> int:
	var ran: int = 0
	for n in roundi(seconds / FRAME):
		ran += driver.advance(FRAME)
	return ran


func test_slow_mo_fast_and_pauses_never_change_the_fight() -> void:
	var played: FightSim = _sim()
	var driver := FightDriver.new(played)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var frames: int = 0
	while not played.is_over():
		frames += 1
		if frames % 37 == 0:
			driver.toggle_slow()
		if frames % 101 == 0:
			driver.toggle_fast()
		driver.paused = frames % 53 < 3
		if driver.held:
			driver.resume()
		driver.advance(rng.randf_range(0.0, 0.25))
	var headless: FightSim = _sim()
	headless.run_to_end()
	assert_eq(played.events.size(), headless.events.size())
	assert_eq(played.events_as_dicts(), headless.events_as_dicts(), "same seed and commands, any speed: the same fight (A13)")


func test_normal_is_2x_fight_time_fast_is_4x_and_slow_mo_is_half_of_normal() -> void:
	var driver := FightDriver.new(_sim())
	assert_eq(_ticks_in(driver, 1.0), 20, "Normal: 2 fight seconds a second")
	driver.toggle_fast()
	assert_eq(_ticks_in(driver, 1.0), 40, "Fast: 4×")
	driver.toggle_fast()
	driver.toggle_slow()
	assert_eq(_ticks_in(driver, 1.0), 10, "slow-mo: 1× fight time")
	driver.toggle_slow()
	driver.normal_rate = 1.0
	assert_eq(_ticks_in(driver, 1.0), 10, "the D91 comparison: Normal at 1×")
	assert_eq(driver.label(), "1×")


func test_a_paused_fight_stands_still_but_calls_still_go_in() -> void:
	var driver := FightDriver.new(_sim())
	_ticks_in(driver, 0.5)
	driver.paused = true
	var at: int = driver.sim.now
	assert_eq(_ticks_in(driver, 1.0), 0)
	assert_eq(driver.label(), "paused")
	assert_true(driver.make_call("pressure"), "calls can be made while paused (docs/01 §2)")
	driver.paused = false
	driver.advance(0.05)
	var heard: Array = driver.sim.events.filter(func(e: FightEvent) -> bool: return e.type == FightEvent.CALL_HEARD and e.actor == 0 and e.data.call_id == "pressure")
	assert_eq(heard.size(), 1)
	assert_eq(heard[0].tick, at, "it lands on the next tick")


func test_the_bell_holds_the_fight_until_the_next_round_is_started() -> void:
	var sim: FightSim = _sim()
	var driver := FightDriver.new(sim)
	var rounds: Array[int] = []
	driver.round_over.connect(func(e: FightEvent) -> void: rounds.append(e.round_number))
	while sim.clock.current_round == 1:
		driver.step()
	assert_true(driver.held)
	assert_eq(rounds, [1])
	var at: int = sim.now
	assert_eq(_ticks_in(driver, 1.0), 0, "nothing happens until the corner is done")
	assert_eq(sim.now, at)
	assert_true(driver.set_rule(2, "catch_kick_and_shoot", 50.0), "rules can change between rounds")
	driver.resume()
	assert_gt(_ticks_in(driver, 0.5), 0)


func test_a_rocked_or_dropped_fighter_slows_the_fight_for_a_moment() -> void:
	var sim: FightSim = _sim()
	var driver := FightDriver.new(sim)
	driver._on_event(FightEvent.new(sim.now, 1, FightEvent.ROCKED, 1, { "by": 0 }))
	assert_true(driver.is_auto_slowed())
	assert_eq(driver.rate(), 1.0)
	assert_string_contains(driver.label(), "slow-mo")
	_ticks_in(driver, FightDriver.AUTO_SLOW_SECONDS + 0.1)
	assert_false(driver.is_auto_slowed())
	assert_eq(driver.rate(), 2.0)
	driver.auto_slow = false
	driver._on_event(FightEvent.new(sim.now, 1, FightEvent.KNOCKDOWN, 1, { "by": 0 }))
	assert_false(driver.is_auto_slowed(), "auto slow-mo can be turned off (D53)")


func test_a_called_move_that_lands_in_the_opening_is_a_perfect_call() -> void:
	var sim: FightSim = _sim()
	var driver := FightDriver.new(sim)
	var flourishes: Array = []
	driver.flourish.connect(func(e: FightEvent) -> void: flourishes.append(e))
	driver._on_event(FightEvent.new(10, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "catch_kick_single", "phase": "telegraph", "by": DecisionLayer.CALL }))
	driver._on_event(FightEvent.new(14, 1, FightEvent.GRAPPLE_WON, 0, { "action_id": "catch_kick_single", "result": PositionLibrary.SUCCESS }))
	assert_eq(flourishes.size(), 1, "the catch off a called takedown")
	assert_true(driver.is_auto_slowed(), "with a moment of slow-mo (D52)")
	driver._on_event(FightEvent.new(30, 1, FightEvent.ACTION_PHASE, 0, { "action_id": "catch_kick_single", "phase": "telegraph", "by": DecisionLayer.RULE }))
	driver._on_event(FightEvent.new(34, 1, FightEvent.GRAPPLE_WON, 0, { "action_id": "catch_kick_single", "result": PositionLibrary.SUCCESS }))
	driver._on_event(FightEvent.new(40, 1, FightEvent.ACTION_PHASE, 1, { "action_id": "double_leg", "phase": "telegraph", "by": DecisionLayer.CALL }))
	driver._on_event(FightEvent.new(44, 1, FightEvent.GRAPPLE_WON, 1, { "action_id": "double_leg", "result": PositionLibrary.SUCCESS }))
	assert_eq(flourishes.size(), 1, "not for a rule's move, nor the opponent's corner")


func test_the_view_slides_between_ticks() -> void:
	var sim: FightSim = _sim()
	var driver := FightDriver.new(sim)
	while sim.fighters[0].pos.is_equal_approx(FightSim.START_POSITIONS[0]):
		driver.step()
	driver.step()
	var before: Vector2 = driver._before[0]
	var now: Vector2 = sim.fighters[0].pos
	driver.advance(0.025)  # Half a tick at Normal.
	assert_almost_eq(driver.alpha(), 0.5, 0.01)
	assert_true(driver.shown_pos(0).is_equal_approx(before.lerp(now, 0.5)))


func test_the_towel_ends_the_fight_at_once() -> void:
	var sim: FightSim = _sim()
	var driver := FightDriver.new(sim)
	var ended: Array = []
	driver.fight_over.connect(func(e: FightEvent) -> void: ended.append(e))
	_ticks_in(driver, 1.0)
	driver.throw_towel()
	assert_true(sim.is_over())
	assert_eq(ended.size(), 1)
	assert_eq(ended[0].data.winner, 1)
	assert_eq(ended[0].data.stopped_by, FightSim.STOPPED_BY_TOWEL)
