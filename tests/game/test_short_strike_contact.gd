extends GutTest
## Short strikes must present the elbow/knee rather than reaching for contact with the hand/foot.

func test_standing_short_strikes_meet_the_target_with_the_visible_striking_joint() -> void:
	var actions: ActionLibrary = ActionLibrary.load_dir()
	var roster: FighterLibrary = FighterLibrary.load_dir()
	for southpaw: bool in [false, true]:
		for action: String in ["elbow", "knee"]:
			var sim := FightSim.new(3, roster.make_pair("muay_thai", "boxer"), actions)
			sim.fighters[0].pos = Vector2(-0.4, 0)
			sim.fighters[1].pos = Vector2(0.4, 0)
			var figures: Array[FighterFigure] = [FighterFigure.new(Color.RED, southpaw), FighterFigure.new(Color.BLUE)]
			for figure in figures:
				add_child(figure)
				figure.use_body(ArenaView.BODY)
			figures[0].opponent = figures[1]
			figures[1].opponent = figures[0]
			sim.fighters[0].action_id = action
			sim.fighters[0].phase = "active"
			sim.fighters[0].phase_ticks_left = 1
			figures[0].show_outcome(action, "landed")
			var spots: Array[Vector2] = ArenaView.strike_spots(sim, [Vector2.ZERO, Vector2(0.8, 0)], [0.0, 0.0])
			for frame in 30:
				figures[1].show_state(sim, 1, spots[1], spots[0], 1.0 / 60.0)
				figures[0].show_state(sim, 0, spots[0], spots[1], 1.0 / 60.0)
				figures[0].body.settle(1.0 / 60.0)
			var body: SkinnedBody = figures[0].body
			var prefix: String = "Left" if southpaw else "Right"
			var joint: Vector3 = body._world_at(prefix + ("ForeArm" if action == "elbow" else "Leg"))
			var tip: Vector3 = body._world_at(prefix + ("Hand" if action == "elbow" else "Foot"))
			var target: Vector3 = figures[1].strike_point("head" if action == "elbow" else "body")
			assert_between(joint.distance_to(target), 0.13, 0.25, "%s %s striking joint reaches the target surface" % [action, prefix])
			assert_gt(tip.distance_to(target), joint.distance_to(target) + 0.08, "%s folds the hand/foot behind the striking joint" % action)
			if action == "elbow":
				var head: Vector3 = figures[0]._head.global_position
				var near: Vector3 = Geometry3D.get_closest_point_to_segment(head, joint, tip)
				assert_gt(near.distance_to(head), 0.17, "the folded forearm stays outside his own head")
			for figure in figures:
				figure.free()


func test_short_strike_blending_preserves_bone_lengths_including_recovery() -> void:
	var root := Vector3(0.2, 1.3, -0.1)
	var chain: Array[Vector3] = FighterMotion.solve_bones(root, root + Vector3(0.1, -0.2, -0.25), Vector3.DOWN, 0.31, 0.32)
	for frame in 61:
		var weight: float = sin(float(frame) / 60.0 * PI)
		var posed: Array[Vector3] = FighterMotion.strike_joint(root, chain, root + Vector3(0.1, 0.2, -0.5), Vector3(0.75, -0.5, 1.0), weight, 0.31, 0.32)
		assert_almost_eq(root.distance_to(posed[0]), 0.31, 0.0001, "upper bone keeps its length")
		assert_almost_eq(posed[0].distance_to(posed[1]), 0.32, 0.0001, "lower bone keeps its length")
