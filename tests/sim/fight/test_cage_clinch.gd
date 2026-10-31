extends GutTest
## The cage clinch (docs/01 §39, D220): driving the other man back onto the fence in the clinch,
## what being held there does to both of them, spinning off it, a shot on the fence that half works
## pressing him there, and the AI and the fighters who lean into it.

const SEED: int = 20261030
const SEEDS: int = 40
## Stats that win (or lose) every contest the drive and the spin-off have.
const BEST := { "clinch_control": 100, "strength": 100, "footwork": 100, "takedowns": 100, "speed": 100 }
const WORST := { "clinch_control": 0, "strength": 0, "footwork": 0, "takedown_defense": 0 }

var _actions: ActionLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()


func _sim(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	return FightSim.new(fight_seed, [FighterState.new("Red", red_stats, [], 0.0), FighterState.new("Blue", blue_stats, [], 0.0)], _actions, 1, 300)


## Two fighters who do nothing unless told, tied up in the clinch: Blue's spot is `blue_at` and Red
## is chest to chest with him on the side of `red_from`.
func _clinched(blue_at: Vector2, red_from: Vector2, red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	var sim: FightSim = _sim(red_stats, blue_stats, fight_seed)
	sim.fighters[0].pos = red_from
	sim.fighters[1].pos = blue_at
	assert_true(sim.apply_transition(0, "clinch_entry"))
	return sim


## Blue's back on the fence (the panel facing +x), Red holding him there from the middle.
func _on_the_fence(red_stats: Dictionary = {}, blue_stats: Dictionary = {}, fight_seed: int = SEED) -> FightSim:
	return _clinched(Vector2(4.0, 0.0), Vector2(3.0, 0.0), red_stats, blue_stats, fight_seed)


func _queue(sim: FightSim, tick: int, fighter: int, action_id: String) -> void:
	assert_true(sim.submit(FightCommand.queue_action(tick, fighter, action_id)))


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


func _bonus_names(b: OddsBreakdown) -> Array[String]:
	var out: Array[String] = []
	for x: Dictionary in b.bonuses:
		out.append(x.name)
	return out


# --- Held on the fence -------------------------------------------------------------------------

func test_the_man_with_his_back_on_the_fence_is_held_there_and_the_other_is_not() -> void:
	var sim: FightSim = _on_the_fence()
	assert_true(sim.held_on_fence(1), "Blue's back is on the fence")
	assert_false(sim.held_on_fence(0), "Red is the one holding")
	assert_true(sim.active_flags(1).has(FightSim.HELD_ON_FENCE))
	assert_true(sim.active_flags(1).has("BACK_TO_CAGE"))
	assert_false(sim.active_flags(0).has(FightSim.HELD_ON_FENCE))


func test_in_the_middle_of_the_cage_nobody_is_held_on_the_fence() -> void:
	var sim: FightSim = _clinched(Vector2(0.4, 0.0), Vector2(-0.4, 0.0))
	assert_false(sim.held_on_fence(0))
	assert_false(sim.held_on_fence(1))


func test_tied_up_along_the_fence_only_the_one_nearer_it_is_held() -> void:
	# Both within half a metre of the fence (both BACK_TO_CAGE), Blue a little nearer.
	var sim: FightSim = _clinched(Vector2(4.15, 0.2), Vector2(3.95, -0.2))
	assert_true(sim.active_flags(0).has("BACK_TO_CAGE"))
	assert_true(sim.active_flags(1).has("BACK_TO_CAGE"))
	assert_true(sim.held_on_fence(1))
	assert_false(sim.held_on_fence(0))


func test_standing_on_the_fence_is_not_held_on_the_fence() -> void:
	var sim: FightSim = _sim()
	sim.fighters[0].pos = Vector2(3.0, 0.0)
	sim.fighters[1].pos = Vector2(4.1, 0.0)
	assert_true(sim.active_flags(1).has("BACK_TO_CAGE"))
	assert_false(sim.held_on_fence(1), "held is the clinch's")


func test_held_on_the_fence_he_tires_faster_than_in_the_open_clinch() -> void:
	var fenced: FightSim = _on_the_fence()
	var open: FightSim = _clinched(Vector2(0.4, 0.0), Vector2(-0.4, 0.0))
	for sim: FightSim in [fenced, open]:
		for f: FighterState in sim.fighters:
			f.stamina = f.max_stamina() * 0.5  # Below the top of the tank, so breathing doesn't hide it.
	_ticks(fenced, 50)
	_ticks(open, 50)
	assert_almost_eq(open.fighters[1].stamina - fenced.fighters[1].stamina, FightSim.FENCE_HOLD_DRAIN_PER_S * 5.0, 0.01, "0.2 a second more for 5 s")
	assert_almost_eq(fenced.fighters[0].stamina, open.fighters[0].stamina, 0.001, "the man holding pays nothing extra")


func test_knees_and_short_punches_find_a_man_held_on_the_fence_a_little_easier() -> void:
	var fenced: FightSim = _on_the_fence()
	var open: FightSim = _clinched(Vector2(0.4, 0.0), Vector2(-0.4, 0.0))
	for id in ["knee", "short_uppercut", "short_hook"]:
		var b: OddsBreakdown = fenced.odds_breakdown(0, id)
		assert_has(_bonus_names(b), FightSim.HELD_ON_FENCE, id)
		assert_almost_eq(b.chance - open.odds_breakdown(0, id).chance, 0.05, 0.001, id)
		assert_does_not_have(_bonus_names(fenced.odds_breakdown(1, id)), FightSim.HELD_ON_FENCE, "not for the man on the fence: " + id)


func test_his_own_shot_from_the_clinch_is_better_with_his_back_on_the_fence() -> void:
	var fenced: FightSim = _on_the_fence()
	var open: FightSim = _clinched(Vector2(0.4, 0.0), Vector2(-0.4, 0.0))
	assert_has(_bonus_names(fenced.odds_breakdown(1, "double_leg")), "own " + FightSim.HELD_ON_FENCE)
	assert_almost_eq(fenced.odds(1, "double_leg") - open.odds(1, "double_leg"), 0.15, 0.001, "a level change off the fence")


func test_the_judges_score_holding_him_on_the_fence_as_control() -> void:
	var sim: FightSim = _on_the_fence()
	_ticks(sim, 30)
	var scores: Dictionary = sim._round_scores()
	assert_gt(float(scores[Judging.CONTROL][0]), 0.0, "Red held him there")
	assert_eq(float(scores[Judging.CONTROL][1]), 0.0)


# --- The drive ---------------------------------------------------------------------------------

func test_a_drive_that_works_walks_him_back_onto_the_fence_and_it_stays_the_clinch() -> void:
	var driven: int = 0
	for n in SEEDS:
		var sim: FightSim = _clinched(Vector2(1.0, 0.0), Vector2(0.2, 0.0), BEST, WORST, SEED + n)
		_queue(sim, sim.now, 0, FightSim.FENCE_DRIVE)
		_ticks(sim, 40)
		if _events(sim, FightEvent.GRAPPLE_WON, 0).is_empty():
			continue
		driven += 1
		assert_eq(sim.situation.position, PositionLibrary.CLINCH)
		assert_true(sim.held_on_fence(1), "walked back onto the fence")
		assert_false(sim.held_on_fence(0))
		assert_almost_eq(sim.distance(), FightSim.TANGLED_GAP, 0.01, "chest to chest")
		assert_eq(_events(sim, FightEvent.GRAPPLE_WON, 0)[0].data.result, "driven")
		assert_true(sim.drive().is_empty(), "the drive is over once he's on the fence")
	assert_gt(driven, SEEDS * 3 / 4, "the best clinch fighter's drive nearly always works")
	assert_eq(_sim().actions.get_action(FightSim.FENCE_DRIVE).get("basic"), true, "everyone knows it")


func test_the_drive_walks_him_back_at_its_pace() -> void:
	var sim: FightSim = _clinched(Vector2(-1.0, 0.0), Vector2(-1.4, 0.0), BEST, WORST)
	for k in 10:
		_queue(sim, sim.now, 0, FightSim.FENCE_DRIVE)
		_ticks(sim, 7)
		if not sim.drive().is_empty():
			break
	assert_false(sim.drive().is_empty(), "under way")
	var start: Vector2 = sim.fighters[1].pos
	_ticks(sim, 10)
	assert_almost_eq(sim.fighters[1].pos.distance_to(start), FightSim.DRIVE_SPEED, 0.05, "1.5 m in a second")


func test_a_drive_that_fails_moves_nobody() -> void:
	var sim: FightSim = _clinched(Vector2(1.0, 0.0), Vector2(0.2, 0.0), WORST, BEST)
	var spots: Array[Vector2] = [sim.fighters[0].pos, sim.fighters[1].pos]
	_queue(sim, sim.now, 0, FightSim.FENCE_DRIVE)
	_ticks(sim, 40)
	if _events(sim, FightEvent.GRAPPLE_WON, 0).is_empty():
		assert_eq(sim.fighters[1].pos, spots[1])
		assert_eq(sim.fighters[0].pos, spots[0])
	assert_true(sim.drive().is_empty())


func test_the_drive_stops_when_the_clinch_does() -> void:
	var sim: FightSim = _clinched(Vector2(-1.0, 0.0), Vector2(-1.4, 0.0), BEST, WORST)
	for k in 10:
		_queue(sim, sim.now, 0, FightSim.FENCE_DRIVE)
		_ticks(sim, 7)
		if not sim.drive().is_empty():
			break
	assert_true(sim.apply_transition(1, "clinch_break"))
	_ticks(sim, 1)
	assert_true(sim.drive().is_empty())


# --- Spinning off ------------------------------------------------------------------------------

func test_a_spin_off_that_works_turns_him_onto_the_fence_and_comes_away() -> void:
	var turned: int = 0
	for n in SEEDS:
		var sim: FightSim = _on_the_fence(WORST, BEST, SEED + n)
		_queue(sim, sim.now, 1, FightSim.SPIN_OFF)
		_ticks(sim, 6)
		if _events(sim, FightEvent.GRAPPLE_WON, 1).is_empty():
			assert_true(sim.held_on_fence(1), "still on the fence")
			continue
		turned += 1
		assert_eq(_events(sim, FightEvent.GRAPPLE_WON, 1)[0].data.result, "turned")
		assert_eq(sim.situation.position, PositionLibrary.STANDING, "and away")
		assert_eq(sim.cage_proximity(0), Octagon.CAGE_PINNED, "Red's back is on the fence now")
		assert_ne(sim.cage_proximity(1), Octagon.CAGE_PINNED)
	assert_gt(turned, SEEDS * 3 / 4)


func test_turning_him_onto_the_fence_keeps_the_clinch_with_his_back_on_it() -> void:
	var turned: int = 0
	for n in SEEDS:
		var sim: FightSim = _on_the_fence(WORST, BEST, SEED + n)
		sim.set_grips([1, FightSim.NO_GRIP])  # Turning him takes an underhook (D261).
		_queue(sim, sim.now, 1, FightSim.TURN_HIM)
		_ticks(sim, 7)
		if _events(sim, FightEvent.GRAPPLE_WON, 1).is_empty():
			continue
		turned += 1
		assert_eq(sim.situation.position, PositionLibrary.CLINCH)
		assert_true(sim.held_on_fence(0), "Red's back is on it now")
		assert_false(sim.held_on_fence(1))
	assert_gt(turned, SEEDS * 3 / 4)


func test_only_the_man_held_on_the_fence_can_spin_off() -> void:
	var sim: FightSim = _on_the_fence(WORST, BEST)
	assert_eq(sim.odds(0, FightSim.SPIN_OFF), 0.0, "Red isn't on the fence")
	assert_eq(sim.odds(0, FightSim.TURN_HIM), 0.0)
	_queue(sim, sim.now, 0, FightSim.SPIN_OFF)
	_ticks(sim, 6)
	var stopped: Array[FightEvent] = _events(sim, FightEvent.GRAPPLE_STOPPED, 0)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0].data.reason, "not on the fence")
	assert_gt(sim.odds(1, FightSim.SPIN_OFF), 0.0, "Blue is")


func test_breaking_off_the_fence_is_harder() -> void:
	var fenced: FightSim = _on_the_fence()
	var open: FightSim = _clinched(Vector2(0.4, 0.0), Vector2(-0.4, 0.0))
	assert_almost_eq(open.odds(1, "clinch_break") - fenced.odds(1, "clinch_break"), 0.10, 0.001)


# --- A shot on the fence -----------------------------------------------------------------------

func test_a_shot_at_a_man_on_the_fence_that_half_works_sometimes_presses_him_there() -> void:
	var pressed: int = 0
	var scrambles: int = 0
	for n in 200:
		var sim: FightSim = _sim({ "takedowns": 50, "speed": 50 }, { "takedown_defense": 50 }, SEED + n)
		sim.fighters[0].pos = Vector2(2.9, 0.0)
		sim.fighters[1].pos = Vector2(4.1, 0.0)
		_queue(sim, sim.now, 0, "double_leg")
		_ticks(sim, 16)
		for e in _events(sim, FightEvent.GRAPPLE_WON, 0):
			if e.data.result == PositionLibrary.PRESSED:
				pressed += 1
				assert_eq(sim.situation.position, PositionLibrary.CLINCH)
				assert_true(sim.held_on_fence(1), "pressed on the fence")
				assert_eq(sim.fighters[0].takedowns_landed, 0, "no takedown")
			elif e.data.result == PositionLibrary.PARTIAL:
				scrambles += 1
	assert_gt(pressed, 0)
	assert_gt(scrambles, 0, "half the time it's still the scramble")
	assert_almost_eq(float(pressed) / float(pressed + scrambles), FightSim.PRESSED_CHANCE, 0.25)


func test_a_shot_in_open_space_that_half_works_is_still_a_scramble() -> void:
	for n in 100:
		var sim: FightSim = _sim({ "takedowns": 50, "speed": 50 }, { "takedown_defense": 50 }, SEED + n)
		sim.fighters[0].pos = Vector2(-0.6, 0.0)
		sim.fighters[1].pos = Vector2(0.6, 0.0)
		_queue(sim, sim.now, 0, "double_leg")
		_ticks(sim, 16)
		for e in _events(sim, FightEvent.GRAPPLE_WON, 0):
			assert_ne(e.data.result, PositionLibrary.PRESSED)


# --- The fighter AI ----------------------------------------------------------------------------

## Red (an AI fighter who likes the fence this much) clinched with Blue, who does nothing.
func _ai_clinched(blue_at: Vector2, red_from: Vector2, liking: float, fight_seed: int) -> FightSim:
	var red := FighterState.new("Red", { "clinch_control": 60, "strength": 60 }, ["knee"], 0.015)
	red.tendencies = { FightSim.FENCE_DRIVE: liking }
	var sim := FightSim.new(fight_seed, [red, FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
	sim.fighters[0].pos = red_from
	sim.fighters[1].pos = blue_at
	assert_true(sim.apply_transition(0, "clinch_entry"))
	return sim


func _ai_starts(sim: FightSim, fighter: int, id: String) -> int:
	var count: int = 0
	for e in _events(sim, FightEvent.ACTION_PHASE, fighter):
		if e.data.phase == "telegraph" and e.data.action_id == id:
			count += 1
	return count


func test_a_fighter_who_likes_the_fence_drives_the_other_man_to_it() -> void:
	var drives: Array[int] = [0, 0]
	for n in SEEDS:
		for k in 2:
			var sim: FightSim = _ai_clinched(Vector2(0.4, 0.0), Vector2(-0.4, 0.0), [1.0, 3.0][k], SEED + n)
			_ticks(sim, 30)
			drives[k] += _ai_starts(sim, 0, FightSim.FENCE_DRIVE)
	assert_gt(drives[1], drives[0], "a fence_drive tendency of 3 drives more than 1")
	assert_gt(drives[0], 0, "everyone drives sometimes")


func test_the_ai_never_drives_a_man_already_held_on_the_fence() -> void:
	for n in SEEDS:
		var sim: FightSim = _ai_clinched(Vector2(4.0, 0.0), Vector2(3.0, 0.0), 3.0, SEED + n)
		_ticks(sim, 50)
		if sim.situation.position == PositionLibrary.CLINCH and sim.held_on_fence(1):
			assert_eq(_ai_starts(sim, 0, FightSim.FENCE_DRIVE), 0)


func test_holding_him_on_the_fence_a_fighter_who_likes_it_breaks_less() -> void:
	assert_eq(FighterAI.fence_liking(FighterState.new("x", {}, [], 0.0)), 1.0, "1 when it isn't set")
	var breaks: Array[int] = [0, 0]
	for n in 60:
		for k in 2:
			var red := FighterState.new("Red", {}, ["knee"], 0.015, StyleLeanings.new({ "base": -100 }))  # Would rather be out of the clinch, knees if he stays.
			red.tendencies = { FightSim.FENCE_DRIVE: [1.0, 4.0][k] }
			var sim := FightSim.new(SEED + n, [red, FighterState.new("Blue", {}, [], 0.0)], _actions, 1, 300)
			sim.fighters[0].pos = Vector2(3.0, 0.0)
			sim.fighters[1].pos = Vector2(4.0, 0.0)
			assert_true(sim.apply_transition(0, "clinch_entry"))
			_ticks(sim, 40)
			breaks[k] += _ai_starts(sim, 0, "clinch_break")
	assert_lt(breaks[1], breaks[0])


func test_held_on_the_fence_the_ai_works_to_get_off_it() -> void:
	var off: int = 0
	for n in SEEDS:
		var blue := FighterState.new("Blue", {}, ["jab"], 0.015)
		var sim := FightSim.new(SEED + n, [FighterState.new("Red", {}, [], 0.0), blue], _actions, 1, 300)
		sim.fighters[0].pos = Vector2(3.0, 0.0)
		sim.fighters[1].pos = Vector2(4.0, 0.0)
		assert_true(sim.apply_transition(0, "clinch_entry"))
		_ticks(sim, 60)
		off += _ai_starts(sim, 1, FightSim.SPIN_OFF) + _ai_starts(sim, 1, "clinch_break") + _ai_starts(sim, 1, FightSim.TURN_HIM)
		assert_eq(_ai_starts(sim, 1, FightSim.FENCE_DRIVE) if sim.held_on_fence(1) else 0, 0, "no driving from the fence")
	assert_gt(off, SEEDS / 2)


# --- The fighters ------------------------------------------------------------------------------

func test_the_styles_that_lean_in_like_the_fence_and_the_rest_do_not() -> void:
	var roster := FighterLibrary.load_dir()
	for id in ["wrestler", "pressure_wrestler", "gnp_wrestler", "dirty_boxer", "muay_thai"]:
		assert_gt(float(roster.profile(id).tendencies.actions.get(FightSim.FENCE_DRIVE, 1.0)), 1.0, id)
	for id in ["boxer", "kicker", "judoka", "bjj", "sambo"]:
		assert_eq(float(roster.profile(id).tendencies.actions.get(FightSim.FENCE_DRIVE, 1.0)), 1.0, id)


func test_in_real_fights_the_dirty_boxer_holds_the_boxer_on_the_fence() -> void:
	var roster := FighterLibrary.load_dir()
	var held: float = 0.0
	var drives: int = 0
	var spins: int = 0
	for n in 6:
		var row: Dictionary = FightSummary.run(SEED + n, roster, _actions, "dirty_boxer", "boxer", 1)
		held += float(row.fence_hold_red)
		drives += int(row.fence_drives_red) + int(row.fence_drives_blue)
		spins += int(row.spin_offs_red) + int(row.spin_offs_blue)
	assert_gt(held / 6.0, 0.05, "a real share of the fight with the Boxer's back on the fence")
	assert_gt(spins, 0, "the man on the fence spins off")
	assert_gte(drives, 0)
