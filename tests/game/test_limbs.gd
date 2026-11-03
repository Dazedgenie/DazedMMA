extends GutTest
## Limbs that stay put (D395; docs/13 "Limbs that stay put"): the skinned body following the pieces sinks its hips
## until both feet on the canvas reach, and a nearly straight leg's knee bends forward instead of swinging about.

var _actions: ActionLibrary
var _roster: FighterLibrary


func before_all() -> void:
	_actions = ActionLibrary.load_dir()
	_roster = FighterLibrary.load_dir()


## A figure with the body, in guard, and the pose its pieces hand the body.
func _figure() -> FighterFigure:
	var sim := FightSim.new(3, _roster.make_pair("boxer", "kicker"), _actions)
	var figure := FighterFigure.new(Color.RED, false, 0)
	add_child_autofree(figure)
	assert_true(figure.use_body(ArenaView.BODY), "the body loads")
	for frame in 3:
		figure.show_state(sim, 0, Vector2.ZERO, Vector2(1.4, 0), 1.0)
	return figure


func _foot(body: SkinnedBody, side: String) -> Vector3:
	return body._world_at("LeftFoot" if side == "l" else "RightFoot")


func test_lifted_hips_sink_until_both_feet_on_the_canvas_reach() -> void:
	var figure: FighterFigure = _figure()
	var pose: Dictionary = figure.body_pose()
	for key: String in ["pelvis_at", "shoulders_at", "shoulder_l", "shoulder_r"]:
		pose[key] = Vector3(pose[key]) + Vector3.UP * 0.12  # His trunk lifted off his feet.
	figure.body.follow_joints(pose)
	for side: String in ["l", "r"]:
		assert_lt(_foot(figure.body, side).distance_to(figure.body._foot_target(pose, side)), 0.02,
			"the %s foot still reaches the canvas" % side)


func test_feet_off_the_canvas_dont_pull_him_down() -> void:
	var figure: FighterFigure = _figure()
	var pose: Dictionary = figure.body_pose()
	for side: String in ["l", "r"]:
		pose["ankle_" + side] = Vector3(pose["ankle_" + side]) + Vector3.UP * 0.6  # Kicks, not feet on the canvas.
	figure.body.follow_joints(pose)
	assert_eq(figure.body._sink_to_feet(pose), 0.0, "nothing to sink for")


func test_a_nearly_straight_legs_knee_bends_forward_not_sideways() -> void:
	var figure: FighterFigure = _figure()
	var pose: Dictionary = figure.body_pose()
	var forward: Vector3 = Basis(pose.pelvis) * Vector3.FORWARD
	for side: String in ["l", "r"]:
		# The pieces' knee a hair off the line from hip to ankle, out to the side: it hardly says which way it bends.
		var hip: Vector3 = pose["hip_" + side]
		var ankle: Vector3 = pose["ankle_" + side]
		var out: Vector3 = Basis(pose.pelvis) * (Vector3.LEFT if side == "l" else Vector3.RIGHT)
		pose["knee_" + side] = hip.lerp(ankle, 0.5) + out * 0.01
	for key: String in ["pelvis_at", "shoulders_at", "shoulder_l", "shoulder_r"]:
		pose[key] = Vector3(pose[key]) + Vector3.UP * 0.08  # So the body's legs have to bend.
	figure.body.follow_joints(pose)
	for side: String in ["l", "r"]:
		var body: SkinnedBody = figure.body
		var hip: Vector3 = body._world_at("LeftUpLeg" if side == "l" else "RightUpLeg")
		var knee: Vector3 = body._world_at("LeftLeg" if side == "l" else "RightLeg")
		var bend: Vector3 = knee - hip.lerp(_foot(body, side), 0.5)
		assert_gt(bend.normalized().dot(forward), 0.5, "the %s knee bends forward" % side)


func test_a_knee_bent_into_the_canvas_turns_up_out_of_it_keeping_its_bones_lengths() -> void:
	var hip := Vector3(0, 0.42, 0)
	var ankle := Vector3(0, 0.07, 0.4)
	var knee := Vector3(0, -0.12, 0.05)  # Bent down through the canvas.
	var lifted: Vector3 = FighterRig.above_canvas(hip, knee, ankle)
	assert_gte(lifted.y, FighterRig.JOINT_FLOOR - 0.001, "the knee is on or above the canvas")
	assert_almost_eq(lifted.distance_to(hip), knee.distance_to(hip), 0.001, "the thigh keeps its length")
	assert_almost_eq(lifted.distance_to(ankle), knee.distance_to(ankle), 0.001, "the shin keeps its length")
	var up := Vector3(0.1, 0.3, -0.1)
	assert_eq(FighterRig.above_canvas(hip, up, ankle), up, "a knee already above it stays put")


func test_a_pose_that_jumps_is_eased_in_not_snapped_to() -> void:
	var figure: FighterFigure = _figure()
	var body: SkinnedBody = figure.body
	var pose: Dictionary = figure.body_pose()
	body.follow_joints(pose)
	body.settle(1.0 / 60.0)
	var hand: Vector3 = body._world_at("LeftHand")
	var jumped: Dictionary = pose.duplicate()
	for key: String in ["elbow_l", "wrist_l"]:
		jumped[key] = Vector3(pose[key]) + Vector3(0.0, -0.8, 0.0)  # The hand thrown 80 cm in one frame.
	body.follow_joints(jumped)
	body.settle(1.0 / 60.0)
	assert_lt(body._world_at("LeftHand").distance_to(hand), 0.15, "it starts moving, not there at once")
	for frame in 60:
		body.follow_joints(jumped)
		body.settle(1.0 / 60.0)
	assert_gt(body._world_at("LeftHand").distance_to(hand), 0.3, "and gets there within a second")


func test_a_quick_strike_is_not_slowed() -> void:
	var figure: FighterFigure = _figure()
	var body: SkinnedBody = figure.body
	var pose: Dictionary = figure.body_pose()
	body.follow_joints(pose)
	body.settle(1.0 / 60.0)
	var moved: Dictionary = pose.duplicate()
	moved.wrist_l = Vector3(pose.wrist_l) + Vector3(0.0, 0.0, -0.12)  # 7 m/s at 60 frames a second: a jab.
	body.follow_joints(moved)
	var want: Vector3 = body._world_at("LeftHand")
	body.settle(1.0 / 60.0)
	assert_lt(body._world_at("LeftHand").distance_to(want), 0.005, "shown where it was thrown")


func test_an_elbow_turned_right_round_its_arm_in_a_frame_is_eased_round() -> void:
	var figure: FighterFigure = _figure()
	var body: SkinnedBody = figure.body
	var pose: Dictionary = figure.body_pose()
	body.follow_joints(pose)
	body.settle(1.0 / 60.0)
	var shoulder: Vector3 = pose.shoulder_l
	var wrist: Vector3 = pose.wrist_l
	var elbow: Vector3 = pose.elbow_l
	var off: Vector3 = (elbow - shoulder) - (elbow - shoulder).project(wrist - shoulder)
	var flipped: Dictionary = pose.duplicate()
	# The same hand, the elbow turned 70° round the arm: too far round to be a move, too short a way to be a jump.
	flipped.elbow_l = elbow - off + off.rotated((wrist - shoulder).normalized(), deg_to_rad(70.0))
	body.follow_joints(flipped)
	var want: Vector3 = body._world_at("LeftForeArm")
	assert_lt(body._furthest_move(), SkinnedBody.POP_SPEED / 60.0, "no joint has jumped")
	body.settle(1.0 / 60.0)
	assert_gt(body._world_at("LeftForeArm").distance_to(want), 0.02, "not flipped over at once")
	for frame in 30:
		body.follow_joints(flipped)
		body.settle(1.0 / 60.0)
	assert_lt(body._world_at("LeftForeArm").distance_to(want), 0.01, "and round within half a second")


func test_a_hand_inside_the_other_mans_trunk_is_put_on_him() -> void:
	var hips := Vector3(0, 0.3, 0)
	var chest := Vector3(0, 0.8, 0)
	var put: Vector3 = FighterRig.out_of(Vector3(0.03, 0.5, 0.0), hips, chest)
	assert_almost_eq(put.distance_to(Vector3(0, 0.5, 0)), FighterRig.TRUNK_RADIUS, 0.001, "on him, not in him")
	assert_gt(put.x, 0.0, "out the side it went in")
	var on_his_back := Vector3(0, 0.6, 0.17)
	assert_eq(FighterRig.out_of(on_his_back, hips, chest), on_his_back, "a hand already on him stays put")


func test_a_knee_inside_the_other_man_turns_out_of_him_keeping_its_bones_lengths() -> void:
	var trunk: Array[Vector3] = [Vector3(0, 0.3, 0.35), Vector3(0, 0.8, 0.35)]  # Him, just in front.
	var hip := Vector3(0, 0.45, 0)
	var ankle := Vector3(0, 0.1, 0.45)
	var knee := Vector3(0, 0.55, 0.3)  # Bent into his belly.
	var turned: Vector3 = FighterRig.clear_of(hip, knee, ankle, trunk)
	var out: float = turned.distance_to(FighterRig.closest_on(turned, trunk[0], trunk[1]))
	assert_gte(out, FighterRig.TRUNK_RADIUS - 0.001, "out of him")
	assert_almost_eq(turned.distance_to(hip), knee.distance_to(hip), 0.001, "the thigh keeps its length")
	assert_almost_eq(turned.distance_to(ankle), knee.distance_to(ankle), 0.001, "the shin keeps its length")


func test_the_body_keeps_its_hands_out_of_the_other_man() -> void:
	var figure: FighterFigure = _figure()
	var body: SkinnedBody = figure.body
	body.follow_joints(figure.body_pose())
	body.settle(1.0 / 60.0)
	var hand: Vector3 = body._world_at("LeftHand")
	body.avoid = [hand + Vector3(0.02, -0.3, 0), hand + Vector3(0.02, 0.3, 0)]  # His trunk right where the hand is.
	body.follow_joints(figure.body_pose())
	body.settle(1.0 / 60.0)
	var now: Vector3 = body._world_at("LeftHand")
	assert_gte(now.distance_to(FighterRig.closest_on(now, body.avoid[0], body.avoid[1])), FighterRig.TRUNK_RADIUS - 0.01,
		"the hand is on him, not in him")
	body.avoid = []
