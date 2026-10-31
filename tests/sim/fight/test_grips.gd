extends GutTest
## Grips in the clinch (docs/01 §40.3, D261): the two sides and who has the inside on each, the
## pummel and the strip, what an underhook, the body lock and the overhook do to the clinch moves,
## turning him on the fence by the underhook, and the AI fighting for them.

const SEED: int = 20261031
const SEEDS: int = 40
## Stats that win (or lose) every contest the grips have.
const BEST := { "clinch_control": 100, "strength": 100, "footwork": 100 }
const WORST := { "clinch_control": 0, "strength": 0, "footwork": 0 }
const NONE: int = FightSim.NO_GRIP

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


## Two fighters who do nothing unless told, tied up in the clinch: Blue at `blue_at`, Red chest to
## chest with him from `red_from` (the middle of the cage by default).
func _clinched(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED,
		blue_at: Vector2 = Vector2(0.4, 0.0), red_from: Vector2 = Vector2(-0.4, 0.0)) -> FightSim:
	var sim := FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = red_from
	sim.fighters[1].pos = blue_at
	assert_true(sim.apply_transition(0, "clinch_entry"))
	return sim


## Blue's back on the fence, Red holding him there.
func _on_the_fence(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	return _clinched(red_stats, blue_stats, fight_seed, Vector2(4.0, 0.0), Vector2(3.0, 0.0))


func _queue(sim: FightSim, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(sim.now, fighter, action_id)))


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


func _bonus(b: OddsBreakdown, name: String) -> float:
	for x: Dictionary in b.bonuses:
		if x.name == name:
			return float(x.value)
	return 0.0


# --- The two sides ----------------------------------------------------------------------------

func test_a_new_clinch_starts_with_no_grips_hand_fighting() -> void:
	var sim: FightSim = _clinched()
	assert_eq(sim.grips(), [NONE, NONE])
	for i in 2:
		assert_eq(sim.underhooks(i), 0)
		for flag in [FightSim.UNDERHOOK, FightSim.BODY_LOCK, FightSim.OVERHOOK]:
			assert_false(sim.active_flags(i).has(flag), flag)


func test_an_underhook_is_the_other_mans_overhook_and_both_is_the_body_lock() -> void:
	var sim: FightSim = _clinched()
	sim.set_grips([0, NONE])
	assert_eq(sim.underhooks(0), 1)
	assert_true(sim.active_flags(0).has(FightSim.UNDERHOOK))
	assert_false(sim.active_flags(0).has(FightSim.BODY_LOCK))
	assert_true(sim.active_flags(1).has(FightSim.OVERHOOK), "his arm on that side is over the top: the whizzer")
	sim.set_grips([0, 1])
	for i in 2:
		assert_true(sim.active_flags(i).has(FightSim.UNDERHOOK), "over-under")
		assert_true(sim.active_flags(i).has(FightSim.OVERHOOK), "over-under")
	sim.set_grips([0, 0])
	assert_true(sim.active_flags(0).has(FightSim.BODY_LOCK))
	assert_eq(sim.underhooks(1), 0)


func test_grips_only_mean_something_in_the_clinch() -> void:
	var sim: FightSim = _clinched()
	sim.set_grips([0, 0])
	assert_true(sim.apply_transition(1, "clinch_break"))
	assert_eq(sim.underhooks(0), 0)
	assert_false(sim.active_flags(0).has(FightSim.BODY_LOCK))
	assert_true(sim.apply_transition(0, "clinch_entry"))
	assert_eq(sim.grips(), [NONE, NONE], "the next clinch starts from hand fighting")


# --- The pummel and the strip -----------------------------------------------------------------

func test_a_pummel_that_works_swims_inside_on_his_side_first() -> void:
	var won: int = 0
	for n in SEEDS:
		var sim: FightSim = _clinched(BEST, WORST, SEED + n)
		sim.set_grips([NONE, 1])
		_queue(sim, 0, FightSim.PUMMEL)
		_ticks(sim, 6)
		var wins: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 0)
		if wins.is_empty():
			continue
		won += 1
		assert_eq(wins[0].data.result, "underhook")
		assert_eq(sim.grips(), [NONE, 0], "his underhook is now Red's: Blue has the overhook there")
		assert_eq(sim.situation.position, PositionLibrary.CLINCH)
	assert_gt(won, SEEDS * 3 / 4)


func test_with_nothing_of_his_to_win_the_pummel_takes_a_free_side_and_two_is_the_body_lock() -> void:
	var sim: FightSim = _clinched(BEST, WORST)
	sim.set_grips([0, NONE])
	for n in 10:
		if sim.underhooks(0) == 2:
			break
		_queue(sim, 0, FightSim.PUMMEL)
		_ticks(sim, 6)
	assert_eq(sim.underhooks(0), 2)
	assert_true(sim.active_flags(0).has(FightSim.BODY_LOCK))


func test_a_pummel_with_the_body_lock_already_has_nothing_to_take() -> void:
	var sim: FightSim = _clinched(BEST, WORST)
	sim.set_grips([0, 0])
	_queue(sim, 0, FightSim.PUMMEL)
	_ticks(sim, 6)
	assert_eq(sim.grips(), [0, 0])
	assert_true(_events(sim, FightEvent.GRAPPLE_WON, 0).is_empty())


func test_a_strip_takes_his_underhook_off_back_to_hand_fighting() -> void:
	var won: int = 0
	for n in SEEDS:
		var sim: FightSim = _clinched(WORST, BEST, SEED + n)
		sim.set_grips([0, 1])
		_queue(sim, 1, FightSim.STRIP_GRIP)
		_ticks(sim, 6)
		var wins: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_WON, 1)
		if wins.is_empty():
			continue
		won += 1
		assert_eq(wins[0].data.result, "stripped")
		assert_eq(sim.grips(), [NONE, 1], "Red's underhook is gone, Blue keeps his")
	assert_gt(won, SEEDS * 3 / 4)


func test_there_is_nothing_to_strip_without_an_underhook_on_you() -> void:
	var sim: FightSim = _clinched(WORST, BEST)
	sim.set_grips([NONE, 1])
	assert_eq(sim.odds(1, FightSim.STRIP_GRIP), 0.0)
	_queue(sim, 1, FightSim.STRIP_GRIP)
	_ticks(sim, 6)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 1)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0].data.reason, "no underhook to strip")


func test_pummeling_is_easier_with_one_underhook_already_and_his_hands_low() -> void:
	var sim: FightSim = _clinched()
	var plain: float = sim.odds(0, FightSim.PUMMEL)
	sim.set_grips([0, NONE])
	assert_almost_eq(sim.odds(0, FightSim.PUMMEL) - plain, 0.05, 0.001, "head position")


# --- What the grips do -------------------------------------------------------------------------

func test_the_underhook_and_the_body_lock_drive_him_to_the_fence_and_his_underhook_stops_it() -> void:
	var sim: FightSim = _clinched()
	var plain: float = sim.odds(0, FightSim.FENCE_DRIVE)
	sim.set_grips([0, NONE])
	assert_almost_eq(sim.odds(0, FightSim.FENCE_DRIVE) - plain, 0.10, 0.001, "an underhook")
	sim.set_grips([0, 0])
	assert_almost_eq(sim.odds(0, FightSim.FENCE_DRIVE) - plain, 0.20, 0.001, "the body lock")
	sim.set_grips([1, NONE])
	assert_almost_eq(sim.odds(0, FightSim.FENCE_DRIVE) - plain, -0.10, 0.001, "his underhook on you")


func test_turning_him_on_the_fence_needs_an_underhook() -> void:
	var sim: FightSim = _on_the_fence()
	assert_eq(sim.odds(1, FightSim.TURN_HIM), 0.0, "no underhook")
	_queue(sim, 1, FightSim.TURN_HIM)
	_ticks(sim, 7)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 1)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0].data.reason, "no underhook")
	assert_true(sim.held_on_fence(1), "still on the fence")
	sim.set_grips([1, NONE])
	var one: float = sim.odds(1, FightSim.TURN_HIM)
	assert_gt(one, 0.0)
	sim.set_grips([1, 1])
	assert_almost_eq(sim.odds(1, FightSim.TURN_HIM) - one, 0.10, 0.001, "better with both")


func test_his_own_underhook_makes_the_turn_harder() -> void:
	var sim: FightSim = _on_the_fence()
	sim.set_grips([1, NONE])
	var free: float = sim.odds(1, FightSim.TURN_HIM)
	sim.set_grips([1, 0])
	assert_almost_eq(sim.odds(1, FightSim.TURN_HIM) - free, -0.10, 0.001, "over-under: the holder's underhook stops the turn (D262)")


func test_turning_him_keeps_the_grips_so_he_can_win_one_back_and_turn_it_again() -> void:
	var sim: FightSim = _on_the_fence(WORST, BEST)
	sim.set_grips([1, 0])
	for n in 10:
		if sim.held_on_fence(0):
			break
		_queue(sim, 1, FightSim.TURN_HIM)
		_ticks(sim, 7)
	assert_true(sim.held_on_fence(0), "Red's back is on the fence now")
	assert_eq(sim.grips(), [1, 0], "the same grips, so the man just turned still has his underhook")
	assert_gt(sim.odds(0, FightSim.TURN_HIM), 0.0, "and he can turn it back")


func test_spinning_off_comes_off_the_overhook_and_the_body_lock_holds_him_there() -> void:
	var sim: FightSim = _on_the_fence()
	var plain: float = sim.odds(1, FightSim.SPIN_OFF)
	sim.set_grips([0, NONE])
	assert_almost_eq(sim.odds(1, FightSim.SPIN_OFF) - plain, 0.10, 0.001, "off the whizzer side")
	sim.set_grips([0, 0])
	assert_almost_eq(sim.odds(1, FightSim.SPIN_OFF) - plain, 0.10 - 0.20, 0.001, "his body lock holds him")


func test_takedowns_and_trips_come_off_the_body_lock_and_his_body_lock_stops_yours() -> void:
	var sim: FightSim = _clinched()
	sim.set_grips([0, 0])
	for id in ["double_leg", "outside_trip"]:
		var b: OddsBreakdown = sim.odds_breakdown(0, id)
		assert_almost_eq(_bonus(b, "own UNDERHOOK") + _bonus(b, "own BODY_LOCK"), 0.20 if id == "double_leg" else 0.15, 0.001, id)
		assert_lt(_bonus(sim.odds_breakdown(1, id), FightSim.BODY_LOCK), 0.0, "Blue can't change level in it: " + id)
	assert_almost_eq(_bonus(sim.odds_breakdown(0, "hip_throw"), "own UNDERHOOK"), 0.05, 0.001)
	sim.set_grips([1, NONE])
	assert_almost_eq(_bonus(sim.odds_breakdown(0, "hip_throw"), "own OVERHOOK"), 0.10, 0.001, "the overhook throw")


func test_short_punches_are_smothered_in_a_body_lock_and_come_off_the_overhook() -> void:
	var sim: FightSim = _clinched()
	sim.set_grips([0, 0])
	for id in ["short_hook", "short_uppercut"]:
		assert_lt(_bonus(sim.odds_breakdown(0, id), "own BODY_LOCK"), 0.0, "both his hands are round him: " + id)
		assert_lt(_bonus(sim.odds_breakdown(1, id), FightSim.BODY_LOCK), 0.0, "smothered: " + id)
	sim.set_grips([0, NONE])
	assert_gt(_bonus(sim.odds_breakdown(1, "short_hook"), "own OVERHOOK"), 0.0, "a free hand off the whizzer")
	assert_gt(_bonus(sim.odds_breakdown(0, "knee"), "own UNDERHOOK"), 0.0, "knees off the underhook")


func test_breaking_out_of_his_body_lock_is_harder() -> void:
	var sim: FightSim = _clinched()
	var plain: float = sim.odds(1, "clinch_break")
	sim.set_grips([0, 0])
	assert_almost_eq(sim.odds(1, "clinch_break") - plain, -0.15, 0.001)


func test_a_shot_pressed_on_the_fence_comes_up_with_an_underhook() -> void:
	var b := OddsBreakdown.new("double_leg")
	b.add_bonus("BACK_TO_CAGE", 0.15)
	var pressed: int = 0
	for n in 60:
		var sim := FightSim.new(SEED + n, [FighterState.new("Red", {}, [], 0.0), FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
		sim.fighters[0].pos = Vector2(3.0, 0.0)
		sim.fighters[1].pos = Vector2(4.0, 0.0)
		if sim._pressed_on_fence(0, _actions.get_action("double_leg"), b, PositionLibrary.PARTIAL):
			pressed += 1
			assert_eq(sim.situation.position, PositionLibrary.CLINCH)
			assert_eq(sim.underhooks(0), 1, "he comes up off the legs with an underhook")
	assert_gt(pressed, 0)


# --- The fighter AI ----------------------------------------------------------------------------

## Red, an AI fighter with this Base leaning, clinched with Blue, who does nothing.
func _ai_clinched(base: float, fight_seed: int, grips: Array[int] = [NONE, NONE]) -> FightSim:
	var red := FighterState.new("Red", { "clinch_control": 60, "strength": 60 }, ["knee"], 0.015, StyleLeanings.new({ "base": base }))
	var sim := FightSim.new(fight_seed, [red, FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(-0.4, 0.0)
	sim.fighters[1].pos = Vector2(0.4, 0.0)
	assert_true(sim.apply_transition(0, "clinch_entry"))
	sim.set_grips(grips)
	return sim


func _ai_starts(sim: FightSim, fighter: int, id: String) -> int:
	var count: int = 0
	for e in _events(sim, FightEvent.ACTION_PHASE, fighter):
		if e.data.phase == "telegraph" and e.data.action_id == id:
			count += 1
	return count


func test_a_fighter_who_likes_the_clinch_pummels_for_underhooks() -> void:
	var pummels: Array[int] = [0, 0]
	for n in SEEDS:
		for k in 2:
			var sim: FightSim = _ai_clinched([20.0, 80.0][k], SEED + n)
			_ticks(sim, 30)
			pummels[k] += _ai_starts(sim, 0, FightSim.PUMMEL)
	assert_gt(pummels[1], pummels[0], "a grappler pummels more")
	assert_gt(pummels[1], 0)


func test_the_ai_never_pummels_with_the_body_lock_already() -> void:
	for n in SEEDS:
		var sim: FightSim = _ai_clinched(80.0, SEED + n, [0, 0])
		_ticks(sim, 5)
		if sim.underhooks(0) == 2:
			assert_eq(_ai_starts(sim, 0, FightSim.PUMMEL), 0)


func test_a_striker_with_an_underhook_on_him_strips_it_more_than_a_grappler() -> void:
	var strips: Array[int] = [0, 0]
	for n in SEEDS:
		for k in 2:
			var red := FighterState.new("Red", {}, ["jab"], 0.015, StyleLeanings.new({ "base": [-80.0, 80.0][k] }))
			var sim := FightSim.new(SEED + n, [red, FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
			sim.fighters[0].pos = Vector2(-0.4, 0.0)
			sim.fighters[1].pos = Vector2(0.4, 0.0)
			assert_true(sim.apply_transition(1, "clinch_entry"))
			sim.set_grips([1, 1])
			_ticks(sim, 20)
			strips[k] += _ai_starts(sim, 0, FightSim.STRIP_GRIP)
	assert_gt(strips[0], strips[1])


## Red holding Blue on the fence, both AI fighters who like the clinch; `grips` set as they tie up.
func _ai_on_the_fence(fight_seed: int, grips: Array) -> FightSim:
	var red := FighterState.new("Red", { "clinch_control": 60, "strength": 60 }, ["knee"], 0.015, StyleLeanings.new({ "base": 60 }))
	var blue := FighterState.new("Blue", { "clinch_control": 60, "strength": 60 }, ["knee"], 0.015, StyleLeanings.new({ "base": 60 }))
	var sim := FightSim.new(fight_seed, [red, blue], _actions, 1, 300)
	sim.fighters[0].pos = Vector2(3.0, 0.0)
	sim.fighters[1].pos = Vector2(4.0, 0.0)
	assert_true(sim.apply_transition(0, "clinch_entry"))
	sim.set_grips([int(grips[0]), int(grips[1])])
	return sim


func test_held_on_the_fence_with_an_underhook_he_turns_him_and_without_one_he_fights_for_it() -> void:
	var turns: Array[int] = [0, 0]
	var pummels: Array[int] = [0, 0]
	for n in SEEDS:
		for k in 2:
			var sim: FightSim = _ai_on_the_fence(SEED + n, [[NONE, NONE], [1, NONE]][k])
			_ticks(sim, 15)
			turns[k] += _ai_starts(sim, 1, FightSim.TURN_HIM)
			pummels[k] += _ai_starts(sim, 1, FightSim.PUMMEL)
	assert_gt(turns[1], turns[0], "he turns it off the underhook (without one he has to win one first)")
	assert_gt(pummels[0], 0, "without one he pummels for it")


func test_holding_him_there_the_ai_takes_his_underhook_away_before_he_turns_it() -> void:
	var pummels: Array[int] = [0, 0]
	for n in SEEDS:
		for k in 2:
			var sim: FightSim = _ai_on_the_fence(SEED + n, [[0, NONE], [0, 1]][k])
			_ticks(sim, 15)
			pummels[k] += _ai_starts(sim, 0, FightSim.PUMMEL)
	assert_gt(pummels[1], pummels[0], "Blue's underhook on the fence makes Red re-pummel")


func test_in_real_fights_the_wrestler_wins_underhooks_against_the_boxer() -> void:
	var roster := FighterLibrary.load_dir()
	var hooks: Array[float] = [0.0, 0.0]
	var pummels: int = 0
	for n in 6:
		var row: Dictionary = FightSummary.run(SEED + n, roster, _actions, "wrestler", "boxer", 1)
		hooks[0] += float(row.underhook_red)
		hooks[1] += float(row.underhook_blue)
		pummels += int(row.pummels_red)
	assert_gt(pummels, 0)
	assert_gt(hooks[0], hooks[1], "the Wrestler has the inside more than the Boxer")
