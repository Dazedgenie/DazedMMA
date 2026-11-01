extends GutTest
## Wind-ups that read (D360): a standing strike shows its tell in the telegraph (smaller for a quicker man and
## the second shot of a combination), travels out over its whole wind-up, kicks chamber before they go out and
## come back through it, the kicking side's arm swings down, and the uppercut comes up under the chin.
## Presentation only: the sim is never changed.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


func _sim() -> FightSim:
	return FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions)


## Fighter 0 is `share` (0 to 1) of the way through `phase` of `action`.
func _at(sim: FightSim, action: String, phase: String, share: float) -> void:
	var f: FighterState = sim.fighters[0]
	f.action_id = action
	f.phase = phase
	var total: int = sim.phase_ticks(f, action, phase)
	f.phase_ticks_left = total
	var ticks: float = share * total
	f.phase_ticks_left = total - int(floor(ticks))
	_fraction = ticks - floor(ticks)


var _fraction: float = 0.0


func _shape(sim: FightSim, action: String, phase: String, share: float) -> Dictionary:
	_at(sim, action, phase, share)
	return FighterFigure.strike_shape(sim, sim.fighters[0], _fraction)


func _pose(sim: FightSim, figure: FighterFigure, action: String, phase: String, share: float) -> Dictionary:
	_at(sim, action, phase, share)
	return figure.pose_for(sim, 0, _fraction)


func test_every_standing_strike_shows_its_tell_by_the_end_of_its_telegraph() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	var rest: Dictionary = FighterFigure._rest_pose()
	for action: String in FighterFigure.TELLS:
		var start: float = float(_shape(sim, action, "telegraph", 0.0).tell)
		var shown: Dictionary = _shape(sim, action, "telegraph", 0.99)
		assert_lt(start, 0.05, "%s: no tell before it starts" % action)
		assert_gt(float(shown.tell), FighterFigure.TELL_SIZE_MIN - 0.01, "%s: the tell is up" % action)
		var pose: Dictionary = _pose(sim, figure, action, "telegraph", 0.99)
		var moved: float = 0.0
		for key: String in FighterFigure.TELLS[action]:
			moved = maxf(moved, absf(float(pose[key]) - float(rest[key])))
		assert_gt(moved, 0.03, "%s: the tell moves him" % action)


func test_the_second_shot_of_a_combination_shows_less_of_a_tell_than_the_first() -> void:
	var sim: FightSim = _sim()
	var first: float = float(_shape(sim, "cross", "telegraph", 0.99).tell)
	var f: FighterState = sim.fighters[0]
	f.combo_id = "one_two"
	f.combo_step = 1
	var second: float = float(_shape(sim, "cross", "telegraph", 0.99).tell)
	assert_lt(second, first, "it flows out of the jab")
	assert_gte(second, FighterFigure.TELL_SIZE_MIN * 0.99, "but never nothing")


func test_a_punch_travels_out_over_its_whole_wind_up() -> void:
	var sim: FightSim = _sim()
	for action: String in ["jab", "cross", "hook", "overhand", "uppercut", "body_hook"]:
		var third: float = float(_shape(sim, action, "windup", 0.33).reach)
		var two_thirds: float = float(_shape(sim, action, "windup", 0.67).reach)
		assert_gt(third, 0.2, "%s: on its way a third of the way through" % action)
		assert_gt(two_thirds, 0.65, "%s: most of the way out two thirds through" % action)
		assert_lt(third, two_thirds, action)
		assert_almost_eq(float(_shape(sim, action, "active", 0.5).reach), 1.0, 0.001, "%s: out" % action)


func test_a_kick_chambers_before_it_goes_out_and_comes_back_through_it() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	for action: String in FighterFigure.KICK_CHAMBER:
		var chambered: Dictionary = _shape(sim, action, "windup", FighterFigure.KICK_LIFT_SHARE)
		assert_gt(float(chambered.chamber), 0.7, "%s: the knee is up" % action)
		assert_lt(float(chambered.reach), 0.25, "%s: before the leg goes out" % action)
		var out: Dictionary = _shape(sim, action, "active", 0.5)
		assert_almost_eq(float(out.chamber), 0.0, 0.001, "%s: no chamber at full extension" % action)
		assert_gt(float(_shape(sim, action, "recovery", 0.5).chamber), 0.5, "%s: back through the chamber" % action)
		var pose: Dictionary = _pose(sim, figure, action, "windup", FighterFigure.KICK_LIFT_SHARE)
		var lead: bool = String(FighterFigure.AIMS[action].limb) == "lead_leg"
		assert_gt(float(pose["leg_lead" if lead else "leg_rear"]), 0.5, "%s: the thigh comes up" % action)
		assert_gt(float(pose["check" if lead else "knee_short"]), 0.7, "%s: the shin folds" % action)


func test_the_kicking_side_s_arm_swings_down_as_a_round_kick_goes_out() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	var guard: float = float(FighterFigure._rest_pose().arm_rear)
	for action: String in ["body_kick", "head_kick", "leg_kick"]:
		var pose: Dictionary = _pose(sim, figure, action, "active", 0.5)
		assert_lt(float(pose.arm_rear), guard - 0.8, action)


func test_the_uppercut_comes_up_under_his_chin() -> void:
	var sim: FightSim = _sim()
	var figures: Array[FighterFigure] = [FighterFigure.new(Color.RED, false, 0), FighterFigure.new(Color.BLUE, false, 1)]
	for figure in figures:
		add_child_autofree(figure)
	figures[0].opponent = figures[1]
	for frame in 3:
		figures[1].show_state(sim, 1, Vector2(0.8, 0), Vector2.ZERO, 1.0)
		figures[0].show_state(sim, 0, Vector2.ZERO, Vector2(0.8, 0), 1.0)
	var root: Vector3 = figures[0]._arm_meshes[1].global_position
	var cross: Vector3 = figures[0].aim_point("cross", root)
	var uppercut: Vector3 = figures[0].aim_point("uppercut", root)
	assert_lt(uppercut.y, cross.y - 0.1, "under the chin, not at his face")
	var low: Dictionary = _pose(sim, figures[0], "uppercut", "windup", 0.0)
	_at(sim, "uppercut", "telegraph", 0.99)
	var tell: Dictionary = figures[0].pose_for(sim, 0, _fraction)
	assert_lt(float(tell.arm_rear), float(FighterFigure._rest_pose().arm_rear) - 0.3, "the hand drops before it comes up")
	assert_lt(float(low.hip_y), FighterFigure.HIP_HEIGHT - 0.1, "he dips first")
	var up: Dictionary = _pose(sim, figures[0], "uppercut", "active", 0.5)
	assert_gt(float(up.hip_y), float(low.hip_y) + 0.05, "then drives up off his legs")


func test_tells_and_chambers_are_only_drawn_standing() -> void:
	var sim: FightSim = _sim()
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	sim.situation.set_to(sim.positions.get_position("clinch"), [PositionLibrary.NEUTRAL, PositionLibrary.NEUTRAL] as Array[String])
	var pose: Dictionary = _pose(sim, figure, "body_kick", "windup", FighterFigure.KICK_LIFT_SHARE)
	assert_almost_eq(float(pose.knee_short), 0.0, 0.001, "no chamber in the clinch")
