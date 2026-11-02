extends GutTest
## Knockdowns from the rig (D370, D371, KnockdownPose): one man's falls and getting up as poses on a rig fitted to the
## Tripo body. Presentation only.

var _sizes: Dictionary
var _rigs: Array[FighterRig] = []


func before_all() -> void:
	var body := SkinnedBody.new()
	add_child(body)
	body.load_body(SkinnedBody.TRIPO_BODY, 1.52)
	_sizes = body.measure()
	body.free()


func before_each() -> void:
	_rigs = []
	for colour: Color in [Color.RED, Color.BLUE]:
		var rig := FighterRig.new(colour)
		add_child_autofree(rig)
		rig.fit(_sizes)
		_rigs.append(rig)


func _pose(spec: Dictionary) -> void:
	KnockdownPose.pose_along(_rigs[0], _rigs[1], [[spec, Transform3D.IDENTITY]], 0.0)


func test_every_way_down_has_its_keys_and_timing() -> void:
	for kind: String in KnockdownPose.KINDS:
		assert_gt(KnockdownPose.falls(kind).size(), 1, kind)
		assert_gt(KnockdownPose.rises(kind).size(), 1, kind)
		assert_true(KnockdownPose.TIMING.has(kind), kind)
		assert_eq(KnockdownPose.rises(kind)[0], KnockdownPose.lying(kind), "%s: gets up from how he fell" % kind)


func test_the_fall_and_getting_up_fit_in_his_time_down() -> void:
	var down: Dictionary = {
		"stiff": FightSim.DOWN_TICKS, "crumple": FightSim.DOWN_TICKS, "fence": FightSim.DOWN_TICKS,
		"liver": FightSim.LIVER_DOWN_TICKS, "leg": FightSim.LEG_DOWN_TICKS,
	}
	for kind: String in KnockdownPose.KINDS:
		var seconds: float = float(down[kind]) / FightClock.TICKS_PER_SECOND
		var timing: Dictionary = KnockdownPose.TIMING[kind]
		assert_lt(float(timing.fall) + float(timing.rise), seconds + 0.001, kind)


func test_every_hand_and_foot_gets_to_its_place() -> void:
	var poses: Dictionary = KnockdownPose.examples()
	for key: String in poses:
		var spec: Dictionary = poses[key]
		_pose(spec)
		for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			if not spec.has(limb):
				continue
			var want: Vector3 = _rigs[0].target_for(spec[limb], limb, Transform3D.IDENTITY, _rigs[1])
			var got: Vector3 = _rigs[0].joints[("wrist_" if limb.begins_with("hand") else "ankle_") + limb.right(1)]
			assert_lt(want.distance_to(got), 0.05, "%s: %s" % [key, limb])


func test_no_one_ends_up_under_the_canvas() -> void:
	var poses: Dictionary = KnockdownPose.examples()
	for key: String in poses:
		_pose(poses[key])
		for spot: String in ["back", "lower_back", "back_of_head", "chest", "belly", "head", "seat"]:
			assert_gt(_rigs[0].point(spot).y, -0.02, "%s: %s" % [key, spot])


func test_flat_on_his_back_he_lies_behind_where_he_stood_and_within_the_room_it_needs() -> void:
	for kind: String in ["stiff", "crumple"]:
		_pose(KnockdownPose.lying(kind))
		var head: Vector3 = _rigs[0].point("head")
		assert_lt(head.y, 0.3, "%s: down" % kind)
		assert_gt(head.z, 0.8, "%s: fell back, away from the other man" % kind)
		assert_lt(head.z, KnockdownPose.LYING_LENGTH, "%s: inside the room the fall is given" % kind)


func test_down_the_fence_he_leans_on_it_but_not_through_it() -> void:
	var keys: Array[Dictionary] = KnockdownPose.falls("fence").slice(1)
	keys.append_array(KnockdownPose.rises("fence"))
	for key: Dictionary in keys:
		_pose(key)
		for spot: String in ["back", "lower_back", "back_of_head", "seat"]:
			assert_lt(_rigs[0].point(spot).z, ScramblePair.FENCE_BACK + 0.02, "%s not through it" % spot)


func test_every_way_up_ends_on_his_feet_and_every_way_down_ends_off_them() -> void:
	for kind: String in KnockdownPose.KINDS:
		var up: Array[Dictionary] = KnockdownPose.rises(kind)
		_pose(up[up.size() - 1])
		assert_gt(_rigs[0].point("head").y, 1.35, "%s: up" % kind)
		_pose(KnockdownPose.lying(kind))
		assert_lt(_rigs[0].point("head").y, 1.15, "%s: down" % kind)


func test_the_fall_quickens_and_getting_up_eases_in_and_out() -> void:
	var half: float = float(KnockdownPose.TIMING.stiff.fall) / 2.0
	assert_lt(KnockdownPose.fall_x(3, half, "stiff"), 1.0, "slower at the start of a fall")
	assert_eq(KnockdownPose.fall_x(3, 10.0, "stiff"), 2.0, "all the way down")
	assert_eq(KnockdownPose.rise_x(4, 0.0, "stiff"), 0.0)
	assert_eq(KnockdownPose.rise_x(4, 10.0, "stiff"), 3.0)
