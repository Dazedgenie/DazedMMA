extends GutTest
## Motion is presentation only: support contacts, pause, and limb reach.


func test_a_step_keeps_the_other_foot_planted_and_pause_freezes_the_swing() -> void:
	var motion := FighterMotion.new()
	var goals: Array[Vector3] = [Vector3(-0.2, 0, -0.2), Vector3(0.2, 0, 0.2)]
	motion.update(goals, [true, true], 0.0)
	var planted: Array[Vector3] = motion.feet.duplicate()
	goals[0].z -= 0.25
	goals[1].z -= 0.25
	motion.update(goals, [true, true], 0.016)
	var swinging: int = motion.swing
	motion.update(goals, [true, true], 0.08)
	assert_gt(motion.feet[swinging].y, 0.04, "a stepping foot clears the canvas")
	assert_eq(motion.feet[1 - swinging], planted[1 - swinging], "the support foot stays fixed in world space")
	var paused: Array[Vector3] = motion.feet.duplicate()
	for frame in 20:
		motion.update(goals, [true, true], 0.0)
	assert_eq(motion.feet, paused, "pause freezes mid-step")
	for frame in 60:
		motion.update(goals, [true, true], 1.0 / 60.0)
	for i in 2:
		assert_lt(motion.feet[i].distance_to(goals[i]), 0.01, "both feet finish in the new stance")
	assert_eq(motion.swing, -1)


func test_releasing_a_kicking_leg_cancels_its_support_step() -> void:
	var motion := FighterMotion.new()
	var goals: Array[Vector3] = [Vector3.ZERO, Vector3.RIGHT]
	motion.update(goals, [true, true], 0.0)
	goals[0].z = -0.3
	motion.update(goals, [true, true], 0.016)
	assert_eq(motion.swing, 0)
	motion.update(goals, [false, true], 0.016)
	assert_eq(motion.swing, -1, "kicks release the step planner")
	goals[0].z = -0.5
	motion.update(goals, [true, true], 0.016)
	assert_eq(motion.feet[0], goals[0], "a returning foot replants at its current stance")


func test_leg_solver_preserves_bone_lengths_and_handles_degenerate_poles() -> void:
	var hip := Vector3(0, 0.85, 0)
	for target: Vector3 in [Vector3(0, 0.1, -0.2), Vector3(0, 0.85, -4), hip, hip + Vector3.UP * 0.2]:
		for pole: Vector3 in [Vector3.FORWARD, Vector3.UP, Vector3.ZERO]:
			var leg: Array[Vector3] = FighterMotion.solve(hip, target, pole)
			assert_true(leg[0].is_finite() and leg[1].is_finite())
			assert_almost_eq(hip.distance_to(leg[0]), FighterMotion.THIGH, 0.0001)
			assert_almost_eq(leg[0].distance_to(leg[1]), FighterMotion.SHIN, 0.0001)


func test_walking_and_retreating_keep_support_contacts_within_leg_reach() -> void:
	var actions := ActionLibrary.load_dir()
	var sim := FightSim.new(3, FighterLibrary.load_dir().make_pair("boxer", "kicker"), actions)
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	var max_error: float = 0.0
	for direction: float in [-1.0, 1.0]:
		for frame in 240:
			var at := Vector2(0, direction * float(frame) / 60.0)
			figure.show_state(sim, 0, at, at + Vector2(0, -1), 1.0 / 60.0)
			for i in 2:
				max_error = maxf(max_error, figure._feet[i].global_position.distance_to(figure.motion.feet[i]))
	assert_lt(max_error, 0.025, "the visible foot should reach the planned contact at 1 m/s")


func test_a_punch_extends_through_windup_and_returns_to_guard_during_recovery() -> void:
	var actions := ActionLibrary.load_dir()
	var sim := FightSim.new(3, FighterLibrary.load_dir().make_pair("boxer", "kicker"), actions)
	var figure := FighterFigure.new(Color.RED)
	add_child_autofree(figure)
	var f: FighterState = sim.fighters[0]
	f.action_id = "cross"
	f.phase = "windup"
	f.phase_ticks_left = sim.phase_ticks(f, "cross", "windup")
	var loaded: Dictionary = figure.pose_for(sim, 0)
	f.phase_ticks_left = 0
	var extended: Dictionary = figure.pose_for(sim, 0)
	assert_gt(extended.reach_rear, loaded.reach_rear + 0.3)
	assert_gt(absf(extended.twist), absf(loaded.twist) + 0.2, "the hips turn with the rear hand")
	f.phase = "recovery"
	f.phase_ticks_left = sim.phase_ticks(f, "cross", "recovery")
	assert_almost_eq(float(figure.pose_for(sim, 0).reach_rear), float(extended.reach_rear), 0.001, "no jump at recovery start")
	f.phase_ticks_left = 0
	assert_almost_eq(float(figure.pose_for(sim, 0).reach_rear), 1.0, 0.001, "back in guard by recovery end")
