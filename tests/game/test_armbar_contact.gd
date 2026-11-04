extends GutTest
## D423: the guard armbar places the trapped elbow at the hips and controls the head with a bent leg.

func test_guard_armbar_isolates_the_arm_across_the_attackers_hips() -> void:
	for attacker in 2:
		_check_armbar(attacker)


func _check_armbar(attacker: int) -> void:
	var sim := FightSim.new(3, FighterLibrary.load_dir().make_pair("bjj", "wrestler"), ActionLibrary.load_dir())
	var roles: Array[String] = [PositionLibrary.BOTTOM, PositionLibrary.TOP]
	if attacker == 1:
		roles.reverse()
	sim.situation.set_to(sim.positions.get_position("full_guard"), roles)
	for i in 2:
		sim.fighters[i].clear_action()
		sim.fighters[i].pos = Vector2(-0.4 if i == 0 else 0.4, 0)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	for frame in 30:
		view._process(1.0 / 30.0)
	assert_true(sim._lock_in(attacker, sim.actions.get_action("armbar")))
	sim._hold.danger = 95.0
	for frame in 120:
		view._process(1.0 / 30.0)
	var a: SkinnedBody = view.figures[attacker].body
	var b: SkinnedBody = view.figures[1 - attacker].body
	assert_lt(b._world_at("RightForeArm").distance_to(a.hips_at()), 0.2, "the trapped elbow is over the hips")
	var shoulder: Vector3 = b._world_at("RightArm")
	var elbow: Vector3 = b._world_at("RightForeArm")
	var wrist: Vector3 = b._world_at("RightHand")
	assert_gt(shoulder.distance_to(wrist) / (shoulder.distance_to(elbow) + elbow.distance_to(wrist)), 0.88, "the trapped arm is nearly straight")
	for hand: String in ["LeftHand", "RightHand"]:
		assert_lt(a._world_at(hand).distance_to(wrist), 0.09, "both hands retain the trapped wrist")
	var head: Vector3 = b._world_at("Head")
	var shin: Vector3 = Geometry3D.get_closest_point_to_segment(head, a._world_at("RightLeg"), a._world_at("RightFoot"))
	assert_between(shin.distance_to(head), 0.12, 0.3, "the leg controls the head without passing through its centre")
	assert_lt(a._world_at("RightFoot").y, a._world_at("RightLeg").y, "the lower leg folds down over the head")
