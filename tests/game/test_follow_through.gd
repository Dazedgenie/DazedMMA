extends GutTest
## Follow-through (D363): standing, a strike's weight goes over his front foot, a miss carries him past and round
## by how committed the shot was (a round kick turns through), a heavy hitter's landed shot drives on through
## while a quick man's punch snaps back to guard, and a rear kick's standing foot turns out on its ball.
## Presentation only: the sim is never changed.

var _actions: ActionLibrary
var _roster: FighterLibrary
var _fraction: float = 0.0


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim(red: String = "boxer") -> FightSim:
	return FightSim.new(3, _roster.make_pair(red, "kicker"), _actions)


func _figure() -> FighterFigure:
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	return figure


## Fighter 0 `share` (0 to 1) of the way through `phase` of `action`, with `outcome` known for it (or "").
func _pose(sim: FightSim, figure: FighterFigure, action: String, phase: String, share: float, outcome: String = "") -> Dictionary:
	var f: FighterState = sim.fighters[0]
	f.action_id = action
	f.phase = phase
	var total: int = sim.phase_ticks(f, action, phase)
	var ticks: float = share * total
	f.phase_ticks_left = total - int(floor(ticks))
	_fraction = ticks - floor(ticks)
	figure.show_outcome(action, outcome)
	return figure.pose_for(sim, 0, _fraction)


func test_his_weight_goes_over_his_front_foot_as_a_punch_goes_out_and_comes_back() -> void:
	var sim: FightSim = _sim()
	var figure: FighterFigure = _figure()
	assert_almost_eq(float(_pose(sim, figure, "cross", "telegraph", 0.0).shift), 0.0, 0.01, "not before it goes")
	var out: float = float(_pose(sim, figure, "cross", "active", 0.5, "covered").shift)
	assert_gt(out, 0.05, "over the front foot behind the cross")
	assert_gt(out, float(_pose(sim, figure, "jab", "active", 0.5, "covered").shift), "more than behind a jab")
	assert_lt(float(_pose(sim, figure, "cross", "recovery", 0.99, "covered").shift), 0.01, "back by the end")


func test_a_miss_carries_him_further_round_and_in_than_a_shot_that_lands() -> void:
	var sim: FightSim = _sim("karate")  # Drives nothing through, so a landed shot carries nothing on.
	var figure: FighterFigure = _figure()
	var landed: Dictionary = _pose(sim, figure, "cross", "recovery", 0.25, "landed")
	var missed: Dictionary = _pose(sim, figure, "cross", "recovery", 0.25, "missed")
	assert_lt(float(missed.twist), float(landed.twist) - 0.1, "the hips carry on round the way the cross turns them")
	assert_lt(float(missed.lean), float(landed.lean) - 0.05, "leaning on in after it")
	assert_gt(float(missed.shift), float(landed.shift) + 0.05, "and further over his front foot")
	var reset: Dictionary = _pose(sim, figure, "cross", "recovery", 0.99, "missed")
	assert_almost_eq(float(reset.shift), 0.0, 0.01, "reset by the end of the recovery")


func test_a_missed_jab_barely_carries_him_but_a_missed_overhand_does() -> void:
	var sim: FightSim = _sim()
	var figure: FighterFigure = _figure()
	var jab: float = float(_pose(sim, figure, "jab", "recovery", 0.25, "missed").shift) - float(_pose(sim, figure, "jab", "recovery", 0.25, "covered").shift)
	var overhand: float = float(_pose(sim, figure, "overhand", "recovery", 0.25, "missed").shift) - float(_pose(sim, figure, "overhand", "recovery", 0.25, "covered").shift)
	assert_lt(jab, 0.03, "a jab: hardly past him")
	assert_gt(overhand, 0.08, "an overhand: well past him")


func test_a_missed_round_kick_turns_him_through_and_the_leg_sweeps_on_across() -> void:
	var sim: FightSim = _sim("karate")
	var figure: FighterFigure = _figure()
	var rest: float = float(_pose(sim, figure, "head_kick", "telegraph", 0.0).twist)
	var landed: float = float(_pose(sim, figure, "head_kick", "recovery", 0.25, "landed").twist)
	var missed: Dictionary = _pose(sim, figure, "head_kick", "recovery", 0.25, "missed")
	assert_gt(absf(float(missed.twist) - rest), absf(landed - rest) + 0.5, "turned on through")
	assert_gt(float(missed.through), 0.7, "the leg carrying on across")
	assert_lt(absf(float(_pose(sim, figure, "head_kick", "recovery", 0.99, "missed").twist) - rest), 0.2, "and back to his stance")


func test_drive_is_power_over_speed() -> void:
	assert_almost_eq(FighterFigure.drive_for(_sim("brawler").fighters[0]), 1.0, 0.001, "the Brawler sits down on it")
	assert_almost_eq(FighterFigure.drive_for(_sim("karate").fighters[0]), 0.0, 0.001, "the Karate man snaps it")
	assert_almost_eq(FighterFigure.drive_for(_sim("check_blue").fighters[0]), 0.5, 0.001, "as quick as he is strong")


func test_a_heavy_hitter_drives_a_landed_punch_through_and_a_quick_one_snaps_it_back() -> void:
	var heavy: FightSim = _sim("brawler")
	var quick: FightSim = _sim("karate")
	var figure: FighterFigure = _figure()
	var through: float = float(_pose(heavy, figure, "cross", "recovery", 0.25, "landed").through)
	assert_gt(through, 0.8, "the Brawler's goes on through")
	assert_almost_eq(float(_pose(quick, figure, "cross", "recovery", 0.25, "landed").through), 0.0, 0.001, "the Karate man's doesn't")
	var heavy_back: float = float(_pose(heavy, figure, "cross", "recovery", 0.6, "landed").reach_rear)
	var quick_back: float = float(_pose(quick, figure, "cross", "recovery", 0.6, "landed").reach_rear)
	assert_lt(quick_back, heavy_back - 0.05, "the quick man's hand is back sooner")
	assert_almost_eq(quick_back, 1.0, 0.02, "back at his guard already")


func test_a_rear_kick_turns_the_standing_foot_out_on_its_ball() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = [FighterFigure.new(Color.RED, false, 0), FighterFigure.new(Color.BLUE, false, 1)]
	for figure in figures:
		add_child_autofree(figure)
	figures[0].opponent = figures[1]
	var f: FighterState = sim.fighters[0]
	var yaw: Array[float] = []
	for action: String in ["cross", "body_kick"]:
		f.action_id = action
		f.phase = "active"
		f.phase_ticks_left = 1
		for frame in 30:
			figures[1].show_state(sim, 1, Vector2(1.0, 0), Vector2.ZERO, 0.05)
			figures[0].show_state(sim, 0, Vector2.ZERO, Vector2(1.0, 0), 0.05)
		var forward: Vector3 = figures[0].global_basis.inverse() * (figures[0]._feet[0].global_basis * Vector3.FORWARD)
		yaw.append(absf(atan2(forward.x, -forward.z)))
	assert_gt(yaw[1], yaw[0] + 0.3, "turned out under the kick")


func test_there_is_no_follow_through_in_the_clinch() -> void:
	var sim: FightSim = _sim()
	var figure: FighterFigure = _figure()
	sim.situation.set_to(sim.positions.get_position("clinch"), [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL] as Array[String])
	var pose: Dictionary = _pose(sim, figure, "short_hook", "recovery", 0.25, "missed")
	assert_almost_eq(float(pose.shift), 0.0, 0.001)
	assert_almost_eq(float(pose.through), 0.0, 0.001)
