extends GutTest
## Misses are announced at contact. Sample the final bodies through follow-through and recovery.
func test_missed_strikes_pass_outside_the_visible_target_and_guard() -> void:
	var actions := ActionLibrary.load_dir()
	var roster := FighterLibrary.load_dir()
	for action: String in ["jab", "cross", "hook", "overhand", "body_kick", "head_kick"]:
		for who in 2:
			for southpaw: bool in [false, true]:
				_check_miss(action, who, southpaw, actions, roster)


func _check_miss(action: String, who: int, southpaw: bool, actions: ActionLibrary, roster: FighterLibrary) -> void:
	var sim := FightSim.new(3, roster.make_pair("kicker", "boxer"), actions)
	for i in 2:
		sim.fighters[i].clear_action()
		sim.fighters[i].pos = Vector2(-0.9 if i == 0 else 0.9, 0)
	var view := ArenaView.new()
	add_child(view)
	view.watch(FightDriver.new(sim))
	view.driver.normal_rate = 1.0
	view.figures[who].lead = 1.0 if southpaw else -1.0
	var limb: String = FighterFigure.AIMS[action].limb
	var side := "Left" if view.figures[who].arm_letter(0 if limb.begins_with("lead") else 1) == "l" else "Right"
	var kick := limb.ends_with("leg")
	for frame in 50:
		view._process(1.0 / 60.0)
	var attacker: SkinnedBody = view.figures[who].body
	var defender: SkinnedBody = view.figures[1 - who].body
	var lower := side + ("Leg" if kick else "ForeArm")
	var end := side + ("Foot" if kick else "Hand")
	var rest := attacker._world_at(lower).distance_to(attacker._world_at(end))
	var target_gap: float = INF
	var guard_gap: float = INF
	var bone_error: float = 0.0
	var previous: Vector3 = attacker._world_at(lower)
	var largest_step: float = 0.0
	for phase: String in ["telegraph", "windup", "active", "recovery"]:
		var ticks := sim.phase_ticks(sim.fighters[who], action, phase)
		for tick in ticks:
			sim.now += 1
			sim.fighters[who].action_id = action
			sim.fighters[who].phase = phase
			sim.fighters[who].phase_ticks_left = ticks - tick
			if who == 1:
				sim.fighters[0].action_id = "slip"
				sim.fighters[0].phase = "active"
				sim.fighters[0].phase_ticks_left = 1
			if phase == "active":
				view.figures[who].show_outcome(action, "missed")
			for frame in 6:
				view.driver._budget = float(frame) / 6.0
				view._process(1.0 / 60.0)
				var joint := attacker._world_at(lower)
				var tip := attacker._world_at(end)
				if phase in ["active", "recovery"]:
					largest_step = maxf(largest_step, joint.distance_to(previous))
				previous = joint
				bone_error = maxf(bone_error, absf(rest - joint.distance_to(tip)))
				if phase not in ["active", "recovery"]:
					continue
				var skull := defender._world_at("Head") + (defender._world_at("Head") - defender._world_at("Neck")).normalized() * 0.08
				if action == "body_kick":
					var trunk := defender.trunk()
					var near := Geometry3D.get_closest_points_between_segments(joint, tip, trunk[0], trunk[1])
					target_gap = minf(target_gap, near[0].distance_to(near[1]))
				else:
					target_gap = minf(target_gap, Geometry3D.get_closest_point_to_segment(skull, joint, tip).distance_to(skull))
				for guard: String in ["Left", "Right"]:
					var near := Geometry3D.get_closest_points_between_segments(joint, tip, defender._world_at(guard + "ForeArm"), defender._world_at(guard + "Hand"))
					guard_gap = minf(guard_gap, near[0].distance_to(near[1]))
	var label := "%s, corner %d southpaw %s" % [action, who, southpaw]
	assert_gt(target_gap, 0.17, label + " clears the target")
	assert_gt(guard_gap, 0.115, label + " clears the guard")
	assert_lt(bone_error, 0.001, label + " preserves limb length")
	assert_lt(largest_step, 0.25, label + " has a continuous follow-through")
	view.free()
