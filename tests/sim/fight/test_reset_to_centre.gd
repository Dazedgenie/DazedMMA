extends GutTest
## Resetting to the centre (D290–D294, docs/01 §20.8): a fighter not having much success walks back
## to the middle of the cage now and then, the patient thinkers most, and a cage cutter can stop it.

const SEED: int = 20261031

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim(red_id: String, blue_id: String, red_at: Vector2, blue_at: Vector2) -> FightSim:
	var sim := FightSim.new(SEED, _roster.make_pair(red_id, blue_id), _actions)
	sim.fighters[0].pos = red_at
	sim.fighters[1].pos = blue_at
	return sim


func _ai(sim: FightSim, i: int) -> FighterAI:
	return sim.decisions[i].ai


func _step_clock(sim: FightSim) -> void:
	sim.now += 1
	for view: FightView in sim.views:
		view.now = sim.now


## Plans fighter 0's feet each tick (nobody moves) until he starts a reset; the tick it started, or -1.
func _until_reset(sim: FightSim, ticks: int) -> int:
	for n in ticks:
		_step_clock(sim)
		_ai(sim, 0)._recent_taken = 40.0  # Still getting the worse of it.
		_ai(sim, 0)._struggle_at = sim.now
		if sim.decisions[0].plan_feet(sim.views[0]).resetting:
			return sim.now
	return -1


func test_taking_clearly_more_than_he_lands_counts_as_struggling() -> void:
	var ai := FighterAI.new()
	ai._recent(0, 20.0, false)
	ai._recent(0, 5.0, true)
	assert_eq(ai.struggling(0), FighterAI.WHY_LOSING)


func test_an_even_exchange_is_not_struggling() -> void:
	var ai := FighterAI.new()
	ai._recent(0, 20.0, false)
	ai._recent(0, 15.0, true)
	ai._recent_thrown = 4.0
	ai._recent_landed = 3.0
	assert_eq(ai.struggling(0), "")


func test_throwing_plenty_and_landing_little_counts_as_struggling() -> void:
	var ai := FighterAI.new()
	ai._recent_thrown = 5.0
	ai._recent_landed = 1.0
	assert_eq(ai.struggling(0), FighterAI.WHY_MISSING, "nothing's landing, even if he isn't getting hit")


func test_a_bad_spell_fades_after_half_a_minute() -> void:
	var ai := FighterAI.new()
	ai._recent(0, 20.0, false)
	assert_eq(ai.struggling(0), FighterAI.WHY_LOSING)
	assert_eq(ai.struggling(300), "", "it halves every 10 s, so 30 s later it's an eighth")


func test_a_patient_fighter_who_is_struggling_walks_back_to_the_middle() -> void:
	# The Counter-striker 3.5 m out with the Brawler off to one side, not in the way.
	var sim := _sim("counter_striker", "brawler", Vector2(3.5, 0.0), Vector2(3.0, 2.0))
	var started: int = _until_reset(sim, 600)
	assert_gt(started, 0, "he resets sooner or later")
	var feet: FeetPlan = sim.decisions[0].plan_feet(sim.views[0])
	assert_true(feet.home, "the way to the middle is clear: he walks straight there")
	assert_eq(feet.cut, 0.0, "and doesn't cut the cage off on the way")
	var before: float = sim.fighters[0].pos.length()
	var apart: float = sim.distance()
	sim._move(0, feet.want, feet.circle, feet.cut, feet.way, feet.anywhere, feet.burst, feet.home)
	assert_lt(sim.fighters[0].pos.length(), before, "closer to the middle")
	assert_gte(sim.distance(), apart - 0.001, "and no closer to the Brawler")


func test_with_the_opponent_in_the_way_he_circles_round_him_toward_the_middle() -> void:
	# The Brawler between the Counter-striker and the middle.
	var sim := _sim("counter_striker", "brawler", Vector2(3.6, 0.0), Vector2(1.8, 0.0))
	assert_gt(_until_reset(sim, 600), 0)
	var feet: FeetPlan = sim.decisions[0].plan_feet(sim.views[0])
	assert_false(feet.home)
	assert_eq(feet.circle, 1.0, "round him, all he can")
	assert_eq(feet.way, 0, "toward the middle side")


func test_a_brawler_never_resets_however_badly_it_goes() -> void:
	var sim := _sim("brawler", "counter_striker", Vector2(3.5, 0.0), Vector2(3.0, 2.0))
	assert_eq(_until_reset(sim, 900), -1, "Pace 70 and Risk 70: no patience at all, he keeps coming")


func test_in_the_middle_already_there_is_nothing_to_reset_to() -> void:
	var sim := _sim("counter_striker", "brawler", Vector2(1.0, 0.0), Vector2(-1.0, 0.0))
	assert_eq(_until_reset(sim, 900), -1)


func test_after_a_reset_he_waits_before_the_next_one() -> void:
	var sim := _sim("counter_striker", "brawler", Vector2(3.5, 0.0), Vector2(3.0, 2.0))
	assert_gt(_until_reset(sim, 600), 0)
	sim.fighters[0].pos = Vector2(0.5, 0.0)  # Made it.
	_step_clock(sim)
	var feet: FeetPlan = sim.decisions[0].plan_feet(sim.views[0])
	assert_false(feet.resetting)
	assert_eq(feet.reset_ended, FighterAI.ENDED_MADE)
	sim.fighters[0].pos = Vector2(3.5, 0.0)
	assert_eq(_until_reset(sim, FighterAI.HOME_EVERY - 2), -1, "not again for %d s" % (FighterAI.HOME_EVERY / FightClock.TICKS_PER_SECOND))


func test_over_whole_fights_resets_are_counted_and_some_are_cut_off() -> void:
	var started: int = 0
	var made: int = 0
	var cut: int = 0
	for n in 4:
		var sim: FightSim = FightSummary.setup(n + 1, _roster, _actions, "counter_striker", "brawler")
		var announced: Array[int] = [0]
		sim.event_emitted.connect(func(e: FightEvent) -> void:
			if e.type == FightEvent.RESET and e.actor == 0:
				announced[0] += 1)
		sim.run_to_end()
		assert_eq(announced[0], sim.resets[0], "every reset is announced in the fight's events")
		assert_lte(sim.resets_made[0] + sim.resets_cut[0], sim.resets[0])
		started += sim.resets[0]
		made += sim.resets_made[0]
		cut += sim.resets_cut[0]
	assert_gt(started, 0, "the Counter-striker resets when the Brawler's getting the better of it")
	assert_gt(made, 0, "some get back to the middle")
	assert_gt(cut, 0, "and the Brawler (Cage cutting 65) shuts some in")


func test_the_fight_log_says_he_walks_back_to_reset() -> void:
	var sim := _sim("counter_striker", "brawler", Vector2(3.5, 0.0), Vector2(3.0, 2.0))
	var event := FightEvent.new(10, 1, FightEvent.RESET, 0, { "why": FighterAI.WHY_MISSING })
	assert_string_contains(FightLogFormatter.describe(event, sim), "walks back to the middle to reset: nothing's landing")
	sim.resets[0] = 2
	sim.resets_made[0] = 1
	assert_string_contains(FightLogFormatter.movement_line(sim, 0), "reset to the middle 2 times (made it 1, cut off 0)")
