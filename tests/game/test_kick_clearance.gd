extends GutTest
## D420: the visible kicking-side forearm must stay outside the raised thigh, throughout the kick.

func test_round_kicks_keep_the_visible_forearm_clear_of_the_thigh_in_both_stances() -> void:
	var actions: ActionLibrary = ActionLibrary.load_dir()
	var roster: FighterLibrary = FighterLibrary.load_dir()
	for southpaw: bool in [false, true]:
		for action: String in ["body_kick", "head_kick", "leg_kick", "calf_kick"]:
			var sim := FightSim.new(3, roster.make_pair("kicker", "boxer"), actions)
			var figures: Array[FighterFigure] = [FighterFigure.new(Color.RED, southpaw), FighterFigure.new(Color.BLUE)]
			for figure in figures:
				add_child(figure)
				figure.use_body(ArenaView.BODY)
			figures[0].opponent = figures[1]
			figures[1].opponent = figures[0]
			var gap: float = FighterFigure.AIMS[action].contact
			for frame in 24:
				figures[1].show_state(sim, 1, Vector2(gap, 0), Vector2.ZERO, 1.0 / 60.0)
				figures[0].show_state(sim, 0, Vector2.ZERO, Vector2(gap, 0), 1.0 / 60.0)
			var prefix: String = "Left" if southpaw else "Right"
			var worst: float = INF
			var where: String = ""
			for phase: String in ["telegraph", "windup", "active", "recovery"]:
				var ticks: int = maxi(1, sim.phase_ticks(sim.fighters[0], action, phase))
				for tick in ticks:
					sim.fighters[0].action_id = action
					sim.fighters[0].phase = phase
					sim.fighters[0].phase_ticks_left = ticks - tick
					sim.now += 1
					for frame in 6:
						figures[1].show_state(sim, 1, Vector2(gap, 0), Vector2.ZERO, 1.0 / 60.0)
						figures[0].show_state(sim, 0, Vector2.ZERO, Vector2(gap, 0), 1.0 / 60.0)
						var body: SkinnedBody = figures[0].body
						body.settle(1.0 / 60.0)
						var points: PackedVector3Array = Geometry3D.get_closest_points_between_segments(
							body._world_at(prefix + "ForeArm"), body._world_at(prefix + "Hand"),
							body._world_at(prefix + "UpLeg"), body._world_at(prefix + "Leg"))
						var gap_now: float = points[0].distance_to(points[1])
						if gap_now < worst:
							worst = gap_now
							where = "%s tick %d frame %d" % [phase, tick, frame]
			assert_gt(worst, 0.18, "%s %s forearm/thigh clearance at %s" % [action, prefix, where])
			for figure in figures:
				figure.free()
