extends GutTest
## D426: final body-lock arms wrap outside the torso, with the head beside the opponent's shoulder.

func test_body_lock_keeps_heads_and_arm_segments_clear_for_either_owner() -> void:
	for owner in 2:
		for lead: float in [-1.0, 1.0]:
			_check_lock(owner, lead)


func _check_lock(owner: int, lead: float) -> void:
	var sim := FightSim.new(3, FighterLibrary.load_dir().make_pair("wrestler", "bjj"), ActionLibrary.load_dir())
	sim.apply_transition(0, "clinch_entry")
	sim.set_grips([owner, owner])
	for i in 2:
		sim.fighters[i].clear_action()
		sim.fighters[i].pos = Vector2(-0.4 if i == 0 else 0.4, 0)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	view.figures[0].lead = lead
	view.figures[1].lead = -lead
	for frame in 60:
		view._process(1.0 / 30.0)
	for i in 2:
		var body: SkinnedBody = view.figures[i].body
		var other: SkinnedBody = view.figures[1 - i].body
		var trunk: Array[Vector3] = other.trunk()
		var head: Vector3 = body._world_at("Head")
		assert_gt(head.distance_to(other._world_at("Head")), 0.23, "heads beside each other")
		assert_gt(head.distance_to(FighterRig.closest_on(head, trunk[0], trunk[1])), 0.2, "head outside the other torso")
		assert_gt(head.distance_to(FighterRig.closest_on(head, other._world_at("LeftArm"), other._world_at("RightArm"))), 0.2,
			"head beside the shoulders rather than inside them")
		for side: String in ["Left", "Right"]:
			assert_gte(FighterRig.limb_clearance(body._world_at(side + "Arm"), body._world_at(side + "ForeArm"), body._world_at(side + "Hand"), trunk),
				FighterRig.TRUNK_RADIUS - 0.005, "%d %s arm wraps around the torso" % [i, side])
