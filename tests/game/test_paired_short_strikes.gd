extends GutTest
## D427: paired elbows and knees land with the joint, with the distal limb folded away.
func test_ground_elbows_use_the_elbow_in_each_legal_position() -> void:
	for action: String in ["ground_elbow", "bottom_elbow"]:
		var positions: Array = ["full_guard", "half_guard", "side_control", "mount", "crucifix"] if action == "ground_elbow" else ["full_guard", "half_guard"]
		for where: String in positions:
			for top in 2:
				for lead: float in [-1.0, 1.0]:
					_check(where, action, top if action == "ground_elbow" else 1 - top, top, lead)
func test_clinch_elbow_and_knee_land_from_the_held_pose() -> void:
	for action: String in ["elbow", "knee"]:
		for who in 2:
			for lead: float in [-1.0, 1.0]:
				for owner in 2:
					_check("clinch", action, who, owner, lead)
func _check(where: String, action: String, who: int, top: int, lead: float) -> void:
	var view: ArenaView = _arrange(where, top, lead)
	var sim: FightSim = view.driver.sim
	sim.fighters[who].action_id = action
	sim.fighters[who].phase = "active"
	sim.fighters[who].phase_ticks_left = 1
	for frame in 3: view._process(1.0)
	var body: SkinnedBody = view.figures[who].body
	var other: SkinnedBody = view.figures[1-who].body
	var side: String = "Left" if view.figures[who].arm_letter(1) == "l" else "Right"
	var knee: bool = action == "knee"
	var middle: Vector3 = body._world_at(side + ("Leg" if knee else "ForeArm"))
	var tip: Vector3 = body._world_at(side + ("Foot" if knee else "Hand"))
	var target: Vector3 = other._world_at("Hips").lerp(other._world_at("Spine2"), 0.65) if knee else other._world_at("Head")
	assert_lt(middle.distance_to(target), 0.24, "%s %s %d joint contact" % [where, action, who])
	assert_gt(tip.distance_to(target), middle.distance_to(target) + 0.05, "%s %s distal limb stays folded away" % [where, action])
	assert_gt(body._world_at("Head").distance_to(other._world_at("Head")), 0.22, "%s %s heads remain separate" % [where, action])
	if where == "clinch":
		for prefix: String in ["Left", "Right"]:
			assert_gte(FighterRig.limb_clearance(body._world_at(prefix + "Arm"), body._world_at(prefix + "ForeArm"), body._world_at(prefix + "Hand"), other.trunk()),
				FighterRig.TRUNK_RADIUS - 0.005, "the striking and supporting arms stay outside the torso")
	view.free()


func _arrange(where: String, top: int, lead: float) -> ArenaView:
	var sim := FightSim.new(3, FighterLibrary.load_dir().make_pair("wrestler", "bjj"), ActionLibrary.load_dir())
	if where == "clinch":
		sim.apply_transition(0, "clinch_entry")
		sim.set_grips([top, top])
	else:
		var roles: Array[String] = [PositionLibrary.TOP, PositionLibrary.BOTTOM]
		if top == 1:
			roles.reverse()
		sim.situation.set_to(sim.positions.get_position(where), roles)
	for i in 2:
		sim.fighters[i].clear_action()
		sim.fighters[i].pos = Vector2(-0.4 if i == 0 else 0.4, 0)
	var view := ArenaView.new()
	add_child(view)
	view.watch(FightDriver.new(sim))
	view.figures[0].lead = lead
	view.figures[1].lead = -lead
	for frame in 3: view._process(1.0)
	return view


func test_short_strike_windup_and_recovery_keep_bone_lengths_and_return_to_the_hold() -> void:
	for case: Array in [["full_guard", "ground_elbow", 0], ["half_guard", "bottom_elbow", 1], ["clinch", "elbow", 0], ["clinch", "knee", 1]]:
		var view: ArenaView = _arrange(case[0], 0, -1.0)
		var sim: FightSim = view.driver.sim
		var who: int = case[2]
		var body: SkinnedBody = view.figures[who].body
		var side: String = "Left" if view.figures[who].arm_letter(1) == "l" else "Right"
		var knee: bool = case[1] == "knee"
		var names: Array[String] = [side + ("UpLeg" if knee else "Arm"), side + ("Leg" if knee else "ForeArm"), side + ("Foot" if knee else "Hand")]
		var first: float = body._world_at(names[0]).distance_to(body._world_at(names[1]))
		var second: float = body._world_at(names[1]).distance_to(body._world_at(names[2]))
		var resting: Vector3 = body._world_at(names[2])
		var previous: Vector3 = body._world_at(names[1])
		var worst_length: float = 0.0
		var worst_step: float = 0.0
		for phase: String in ["telegraph", "windup", "active", "recovery"]:
			var ticks: int = sim.phase_ticks(sim.fighters[who], case[1], phase)
			for tick in ticks:
				sim.fighters[who].action_id = case[1]
				sim.fighters[who].phase = phase
				sim.fighters[who].phase_ticks_left = ticks - tick
				for frame in 6:
					view.driver._budget = float(frame) / 6.0
					view._process(1.0 / 60.0)
					var middle: Vector3 = body._world_at(names[1])
					worst_step = maxf(worst_step, middle.distance_to(previous))
					previous = middle
					worst_length = maxf(worst_length, absf(body._world_at(names[0]).distance_to(middle) - first))
					worst_length = maxf(worst_length, absf(middle.distance_to(body._world_at(names[2])) - second))
		assert_lt(worst_length, 0.001, "%s keeps both bone lengths throughout the strike" % case[1])
		assert_lt(worst_step, 0.25, "%s has no single-frame joint jump" % case[1])
		sim.fighters[who].clear_action()
		view.driver._budget = 0.0
		for frame in 60:
			view._process(1.0 / 60.0)
		assert_lt(body._world_at(names[2]).distance_to(resting), 0.03, "%s returns to the hold" % case[1])
		assert_true(view._clinch_rigs[who].joint_strikes.is_empty(), "no stale joint target after recovery")
		view.free()
