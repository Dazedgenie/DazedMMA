extends GutTest
## The sprawl reflex minigame (sim/world/sprawl_reflex.gd, docs/03 §13.5, D411): the partner's shots and feints in the
## fight engine, a sprawl in time stuffing the shot, a late one or none getting him taken down and stood back up, a
## jumpy one or a bite on the feint costing, the session's score, and the drill getting harder with his Takedown defence.

var _roster: FighterLibrary
var _actions: ActionLibrary
var _him: Dictionary


func before_all() -> void:
	_roster = FighterLibrary.load_dir()
	_actions = ActionLibrary.load_dir()
	_him = StyleLibrary.shared().generate("boxer", 4, 0, _roster)


func _drill(level: float = 50.0, fatigue: float = 0.0, s: int = 3) -> SprawlReflex:
	return SprawlReflex.new(_him, level, fatigue, s, _roster, _actions)


## Runs the drill to its end, sprawling as each double leg's wind-up starts (the level change) when `sprawl_shots`,
## and as each feint starts when `bite`.
func _play(d: SprawlReflex, sprawl_shots: bool, bite: bool = false) -> void:
	var guard: int = 0
	while not d.is_over() and guard < 5000:
		guard += 1
		var p: FighterState = d.sim.fighters[1]
		if sprawl_shots and p.action_id == "double_leg" and p.phase == "windup":
			d.press()
		if bite and p.action_id == "feint" and p.phase == "telegraph":
			d.press()
		d.tick()


func test_a_sprawl_as_he_changes_levels_stuffs_every_shot() -> void:
	var d: SprawlReflex = _drill()
	_play(d, true)
	assert_gt(d.counts[SprawlReflex.STUFFED], 10, "a minute of shots")
	assert_eq(d.counts[SprawlReflex.TAKEN_DOWN], 0)
	assert_eq(d.counts[SprawlReflex.STRAY], 0)
	assert_almost_eq(d.quality(), TrainingCamp.PLAYED_MAX, 0.001)


func test_no_sprawl_and_every_shot_takes_him_down_then_they_stand_back_up() -> void:
	var d: SprawlReflex = _drill()
	var first: FightSim = d.sim
	_play(d, false)
	assert_eq(d.counts[SprawlReflex.STUFFED], 0)
	assert_gt(d.counts[SprawlReflex.TAKEN_DOWN], 5, "taken down, stood back up, and again")
	assert_ne(d.sim, first, "a fresh sim after each takedown")
	assert_almost_eq(d.quality(), TrainingCamp.PLAYED_MIN, 0.001)


func test_a_sprawl_with_nothing_there_costs_and_one_on_a_feint_is_a_bite() -> void:
	var d: SprawlReflex = _drill(80.0)  # More feints.
	_play(d, true, true)
	assert_true(d.reps.has("feint") or d.reps.has("feint_shot"))
	assert_gt(d.counts[SprawlReflex.BIT], 0, "he sold the feint")
	assert_lt(d.accuracy(), 1.0)
	var jumpy: SprawlReflex = _drill()
	for i in 3:  # The first rep comes SETTLE_SECONDS in.
		jumpy.tick()
	assert_true(jumpy.press(), "free to sprawl")
	for i in 9:
		jumpy.tick()
	assert_eq(jumpy.counts[SprawlReflex.STRAY], 1, "a sprawl before anything came")


func test_he_cannot_sprawl_again_while_still_in_one() -> void:
	var d: SprawlReflex = _drill()
	for i in 5:
		d.tick()
	assert_true(d.press())
	d.tick()
	assert_false(d.press(), "still sprawling")


func test_the_same_seed_runs_the_same_drill() -> void:
	var a: SprawlReflex = _drill()
	var b: SprawlReflex = _drill()
	_play(a, true)
	_play(b, true)
	assert_eq(a.reps, b.reps)
	assert_eq(a.counts, b.counts)


func test_a_better_sprawler_gets_a_quicker_drill_with_more_feints_and_tiredness_quickens_it() -> void:
	var low: SprawlReflex = _drill(20.0)
	var high: SprawlReflex = _drill(90.0)
	assert_lt(high.gap, low.gap)
	assert_gt(high.feint_share, low.feint_share)
	assert_gt(high.speed, low.speed)
	assert_gt(_drill(50.0, 100.0).speed, _drill(50.0, 0.0).speed)
	assert_almost_eq(low.seconds_left(), SprawlReflex.ROUND_SECONDS, 0.2, "a minute on screen at any speed (D38)")
	assert_almost_eq(high.seconds_left(), SprawlReflex.ROUND_SECONDS, 0.2)


func test_a_drill_sim_changes_nothing_in_a_fight() -> void:
	var a := FightSim.new(9, [_roster.make("wrestler"), _roster.make("boxer")] as Array[FighterState], _actions)
	var b := FightSim.new(9, [_roster.make("wrestler"), _roster.make("boxer")] as Array[FighterState], _actions)
	a.run_to_end()
	b.run_to_end()
	assert_false(a.drill)
	assert_eq(a.events.size(), b.events.size())
