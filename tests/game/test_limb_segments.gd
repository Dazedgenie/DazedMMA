extends GutTest
## A limb can cross a torso even though its elbow and wrist both lie outside it.

func test_a_forearm_crossing_the_trunk_is_routed_around_it_without_stretching() -> void:
	var trunk: Array[Vector3] = [Vector3(0, 0.4, 0), Vector3(0, 1.4, 0)]
	var root := Vector3(-0.35, 0.9, 0.2)
	var middle := Vector3(0.2, 1.0, 0)
	var tip := Vector3(-0.35, 1.1, 0)
	assert_gt(middle.distance_to(FighterRig.closest_on(middle, trunk[0], trunk[1])), FighterRig.TRUNK_RADIUS)
	assert_gt(tip.distance_to(FighterRig.closest_on(tip, trunk[0], trunk[1])), FighterRig.TRUNK_RADIUS)
	var routed: Vector3 = FighterRig.clear_of(root, middle, tip, trunk)
	for segment: Array in [[root, routed], [routed, tip]]:
		var near: PackedVector3Array = Geometry3D.get_closest_points_between_segments(segment[0], segment[1], trunk[0], trunk[1])
		assert_gte(near[0].distance_to(near[1]), FighterRig.TRUNK_RADIUS - 0.001, "the whole segment stays outside")
	assert_almost_eq(root.distance_to(routed), root.distance_to(middle), 0.0001)
	assert_almost_eq(routed.distance_to(tip), middle.distance_to(tip), 0.0001)


func test_back_control_forearms_and_hooks_clear_the_final_opponents_torso() -> void:
	var sim := FightSim.new(3, FighterLibrary.load_dir().make_pair("wrestler", "bjj"), ActionLibrary.load_dir())
	sim.situation.set_to(sim.positions.get_position("back_control"), [PositionLibrary.TOP, PositionLibrary.BOTTOM])
	for i in 2:
		sim.fighters[i].clear_action()
		sim.fighters[i].pos = Vector2(-0.4 if i == 0 else 0.4, 0)
	var view := ArenaView.new()
	add_child_autofree(view)
	view.watch(FightDriver.new(sim))
	for frame in 60:
		view._process(1.0 / 30.0)
	for i in 2:
		var body: SkinnedBody = view.figures[i].body
		var trunk: Array[Vector3] = view.figures[1 - i].body.trunk()
		for limb: Array in SkinnedBody.LIMBS:
			assert_gte(FighterRig.limb_clearance(body._world_at(limb[0]), body._world_at(limb[1]), body._world_at(limb[2]), trunk),
				FighterRig.TRUNK_RADIUS - 0.005, "%d %s stays outside the torso" % [i, limb[0]])
