extends GutTest
## Blocking contacts must meet the visible guard or raised shin, outside the protected body.

func test_blocked_strikes_meet_the_visible_defending_limb() -> void:
	for southpaw: bool in [false, true]:
		for defence_southpaw: bool in [false, true]:
			for who in 2:
				for action: String in ["cross", "body_kick", "leg_kick", "calf_kick"]:
					var view: ArenaView = _arrange(action, southpaw, defence_southpaw, who)
					var figures: Array[FighterFigure] = [view.figures[who], view.figures[1 - who]]
					for frame in 60:
						view._process(1.0 / 60.0)
					var attack: SkinnedBody = figures[0].body
					var defend: SkinnedBody = figures[1].body
					var side: String = "Left" if southpaw else "Right"
					var tip: Vector3 = attack._world_at(side + ("Hand" if action == "cross" else "Foot"))
					var middle: Vector3 = attack._world_at(side + ("ForeArm" if action == "cross" else "Leg"))
					var clearance: float = INF
					for guard_side: String in ["Left", "Right"]:
						if action in ["leg_kick", "calf_kick"] and guard_side != ("Right" if defence_southpaw else "Left"):
							continue
						var guard_a: Vector3 = defend._world_at(guard_side + ("Leg" if action in ["leg_kick", "calf_kick"] else "ForeArm"))
						var guard_b: Vector3 = defend._world_at(guard_side + ("Foot" if action in ["leg_kick", "calf_kick"] else "Hand"))
						var near: PackedVector3Array = Geometry3D.get_closest_points_between_segments(middle, tip, guard_a, guard_b)
						clearance = minf(clearance, near[0].distance_to(near[1]))
					print("DEFENCE ", action, " ", southpaw, "/", defence_southpaw, " clearance=", clearance)
					assert_between(clearance, 0.07, 0.18, "%s %s/%s meets the defending limb without passing through it" % [action, southpaw, defence_southpaw])
					var protected: Array[Vector3] = defend.trunk()
					var near_body: PackedVector3Array = Geometry3D.get_closest_points_between_segments(middle, tip, protected[0], protected[1])
					assert_gt(near_body[0].distance_to(near_body[1]), 0.17, "blocked limb remains outside the protected torso")
					if action in ["leg_kick", "calf_kick"]:
						var check_side: String = "Right" if defence_southpaw else "Left"
						var thigh: PackedVector3Array = Geometry3D.get_closest_points_between_segments(
							attack._world_at(side + "UpLeg"), middle, defend._world_at(check_side + "UpLeg"), defend._world_at(check_side + "Leg"))
						print("THIGHS ", southpaw, "/", defence_southpaw, " ", thigh[0].distance_to(thigh[1]))
						assert_gt(thigh[0].distance_to(thigh[1]), 0.18, "the two raised thighs remain separate")
					view.free()


func test_defence_motion_preserves_lengths_and_returns_to_guard() -> void:
	for action: String in ["cross", "body_kick", "leg_kick"]:
		var view: ArenaView = _arrange(action, true, false)
		var sim: FightSim = view.driver.sim
		for fighter in sim.fighters:
			fighter.clear_action()
		for frame in 60:
			view._process(1.0 / 60.0)
		var bodies: Array[SkinnedBody] = [view.figures[0].body, view.figures[1].body]
		var lengths: Array[float] = []
		for body in bodies:
			for limb: Array in SkinnedBody.LIMBS:
				for segment in 2:
					lengths.append(body._world_at(limb[segment]).distance_to(body._world_at(limb[segment + 1])))
		var rest: Vector3 = bodies[1]._world_at("LeftHand") - bodies[1]._world_at("Head")
		var max_error: float = 0.0
		var max_step: float = 0.0
		var previous: Array[Vector3] = []
		for phase: String in ["telegraph", "windup", "active", "recovery", "idle"]:
			var ticks: int = 10 if phase == "idle" else sim.phase_ticks(sim.fighters[0], action, phase)
			for tick in ticks:
				sim.now += 1
				sim.fighters[0].action_id = action
				sim.fighters[0].phase = phase
				sim.fighters[0].phase_ticks_left = ticks - tick
				sim.fighters[1].action_id = "check_kick" if action in ["leg_kick", "calf_kick"] else "cover_up"
				sim.fighters[1].phase = "active" if phase != "recovery" else "recovery"
				sim.fighters[1].phase_ticks_left = 1
				# The result is revealed at contact, as in a live fight, rather than known through wind-up.
				if phase == "active":
					view.figures[0].show_outcome(action, "checked" if action in ["leg_kick", "calf_kick"] else "covered")
				if phase == "idle":
					for fighter in sim.fighters:
						fighter.clear_action()
				for frame in 6:
					view.driver._budget = float(frame) / 6.0
					view._process(1.0 / 60.0)
					var index: int = 0
					var current: Array[Vector3] = []
					for body in bodies:
						for limb: Array in SkinnedBody.LIMBS:
							for segment in 2:
								var length: float = body._world_at(limb[segment]).distance_to(body._world_at(limb[segment + 1]))
								max_error = maxf(max_error, absf(length - lengths[index]))
								index += 1
							current.append(body._world_at(limb[1]))
					# Measure the correction/release introduced by the block; punch wind-up remains a separate S04 audit.
					if not previous.is_empty() and phase in ["active", "recovery", "idle"]:
						for i in current.size():
							max_step = maxf(max_step, current[i].distance_to(previous[i]))
					previous = current
		assert_lt(max_error, 0.001, action + " keeps limb lengths throughout the block and recovery")
		assert_lt(max_step, 0.20, action + " block and release have no abrupt one-frame joint jump")
		var returned: Vector3 = bodies[1]._world_at("LeftHand") - bodies[1]._world_at("Head")
		assert_lt(returned.distance_to(rest), 0.03, action + " returns to the original guard")
		view.free()


func test_unblocked_body_shot_does_not_lower_high_guard() -> void:
	var view: ArenaView = _arrange("body_kick")
	view.driver.sim.fighters[1].action_id = "high_guard"
	view.figures[0].show_outcome("body_kick", "landed")
	for frame in 60:
		view._process(1.0 / 60.0)
	assert_almost_eq(float(view.figures[1]._pose.body_cover), 0.0, 0.001, "the high guard still leaves the ribs open on an unblocked body hit")
	view.free()


func _arrange(action: String, southpaw: bool = false, defence_southpaw: bool = false, who: int = 0) -> ArenaView:
	var sim := FightSim.new(3, FighterLibrary.load_dir().make_pair("kicker", "boxer"), ActionLibrary.load_dir())
	for i in 2:
		sim.fighters[i].clear_action()
		sim.fighters[i].pos = Vector2(-0.9 if i == 0 else 0.9, 0)
	var view := ArenaView.new()
	add_child(view)
	view.watch(FightDriver.new(sim))
	view.driver.normal_rate = 1.0
	view.figures[who].lead = 1.0 if southpaw else -1.0
	view.figures[1 - who].lead = 1.0 if defence_southpaw else -1.0
	for frame in 60:
		view._process(1.0 / 60.0)
	sim.fighters[who].action_id = action
	sim.fighters[1 - who].action_id = "check_kick" if action in ["leg_kick", "calf_kick"] else "cover_up"
	for fighter in sim.fighters:
		fighter.phase = "active"
		fighter.phase_ticks_left = 1
	view.figures[who].show_outcome(action, "checked" if action in ["leg_kick", "calf_kick"] else "covered")
	return view
