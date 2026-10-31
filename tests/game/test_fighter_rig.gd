extends GutTest
## The rig prototype (D283): a code skeleton whose hands and feet reach points on the other man, posed in pairs.
## Presentation only.

var _rigs: Array[FighterRig] = []


func before_each() -> void:
	_rigs = []
	for colour: Color in [Color.RED, Color.BLUE]:
		var rig := FighterRig.new(colour)
		add_child_autofree(rig)
		_rigs.append(rig)


func _pose(pair: Dictionary, to: Dictionary = {}, t: float = 0.0) -> void:
	FighterRig.pose_pair(_rigs[0], _rigs[1], pair, Transform3D.IDENTITY, to, t)


## How deep `rig`'s torso and head go inside the other man's core (a 9 cm rod from his hips to his neck):
## positive means into him.
func _depth_into(rig: FighterRig, other: FighterRig, keys: Array = ["pelvis", "waist", "neck", "head"]) -> float:
	var from: Vector3 = other.bones.pelvis.global_position
	var to: Vector3 = other.point("neck")
	var deepest: float = -INF
	for key: String in keys:
		var bone: Node3D = rig.bones[key]
		for child: Node in bone.find_children("*", "MeshInstance3D", false, false):
			var mesh: MeshInstance3D = child
			for v: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = mesh.to_global(v)
				var on: Vector3 = Geometry3D.get_closest_point_to_segment(p, from, to)
				deepest = maxf(deepest, 0.09 - p.distance_to(on))
	return deepest


func _blends() -> Array:
	var out: Array = []
	for clip: Array in RigPairs.clips():
		if not (clip[1] as Dictionary).is_empty():
			out.append(clip)
	return out


func _reach_miss(pose: Dictionary) -> Dictionary:
	var worst := {"miss": 0.0, "what": ""}
	for i in 2:
		var spec: Dictionary = pose["a" if i == 0 else "b"]
		for key: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			if not spec.has(key):
				continue
			var want: Vector3 = _rigs[i].target_for(spec[key], key, Transform3D.IDENTITY, _rigs[1 - i])
			var got: Vector3 = _rigs[i].joints[("wrist_" if key.begins_with("hand") else "ankle_") + key.right(1)]
			if want.distance_to(got) > float(worst.miss):
				worst = {"miss": want.distance_to(got), "what": "%s %s" % ["red" if i == 0 else "blue", key]}
	return worst


func _check_lengths(label: String) -> void:
	for rig in _rigs:
		for side: String in FighterRig.SIDES:
			var j: Dictionary = rig.joints
			assert_almost_eq(Vector3(j["shoulder_" + side]).distance_to(j["elbow_" + side]), FighterRig.UPPER_ARM, 0.002, label)
			assert_almost_eq(Vector3(j["elbow_" + side]).distance_to(j["wrist_" + side]), FighterRig.FOREARM, 0.002, label)
			assert_almost_eq(Vector3(j["hip_" + side]).distance_to(j["knee_" + side]), FighterRig.THIGH, 0.002, label)
			assert_almost_eq(Vector3(j["knee_" + side]).distance_to(j["ankle_" + side]), FighterRig.SHIN, 0.002, label)


func test_the_bones_keep_their_length_in_every_pose_and_every_blend() -> void:
	var poses: Dictionary = RigPairs.all()
	for pose_name: String in poses:
		_pose(poses[pose_name])
		_check_lengths(pose_name)
	for clip: Array in _blends():
		for t: float in [0.25, 0.5, 0.75]:
			_pose(clip[1], clip[2], t)
			_check_lengths("%s at %.2f" % [clip[0], t])


func test_every_hand_and_foot_gets_to_its_place_on_the_other_man() -> void:
	var poses: Dictionary = RigPairs.all()
	for pose_name: String in poses:
		_pose(poses[pose_name])
		var worst: Dictionary = _reach_miss(poses[pose_name])
		assert_lt(float(worst.miss), 0.03, "%s: %s is %.0f cm short" % [pose_name, worst.what, float(worst.miss) * 100.0])


func test_the_bodies_touch_but_do_not_pass_through_each_other() -> void:
	var poses: Dictionary = RigPairs.all()
	for pose_name: String in poses:
		_pose(poses[pose_name])
		assert_lt(_depth_into(_rigs[0], _rigs[1]), 0.03, "%s: red's body inside blue's" % pose_name)
		assert_lt(_depth_into(_rigs[1], _rigs[0]), 0.03, "%s: blue's body inside red's" % pose_name)
	for pose_name: String in ["clinch", "sprawl"]:  # Chest to chest, and chest on his back.
		_pose(poses[pose_name])
		assert_gt(maxf(_depth_into(_rigs[0], _rigs[1]), _depth_into(_rigs[1], _rigs[0])), -0.1, "%s: pressed together" % pose_name)


func test_in_the_full_guard_his_ankles_cross_behind_the_top_mans_back() -> void:
	_pose(RigPairs.full_guard())
	var top: FighterRig = _rigs[0]
	var bottom: FighterRig = _rigs[1]
	var behind: Vector3 = top.bones.pelvis.global_basis.z  # Red faces -Z: his back is +Z.
	for side: String in FighterRig.SIDES:
		var ankle: Vector3 = bottom.joints["ankle_" + side]
		assert_gt((ankle - top.point("lower_back")).dot(behind), -0.02, "the %s ankle is round behind him" % side)
	assert_lt(Vector3(bottom.joints.ankle_l).distance_to(bottom.joints.ankle_r), 0.2, "crossed together")


func test_nothing_goes_through_the_canvas_and_standing_feet_stay_on_it() -> void:
	var poses: Dictionary = RigPairs.all()
	for pose_name: String in poses:
		_pose(poses[pose_name])
		for rig in _rigs:
			for key: String in rig.joints:
				assert_gt(Vector3(rig.joints[key]).y, 0.03, "%s: %s above the canvas" % [pose_name, key])
	for pose_name: String in ["standing", "clinch", "back_up"]:
		_pose(poses[pose_name])
		for rig in _rigs:
			for side: String in FighterRig.SIDES:
				assert_almost_eq(Vector3(rig.joints["ankle_" + side]).y, FighterRig.ANKLE_UP, 0.01, "%s: feet on the canvas" % pose_name)


func test_a_humanoid_body_could_be_driven_from_the_same_joints() -> void:
	_pose(RigPairs.clinch())
	var named: Dictionary = _rigs[0].bone_transforms()
	for bone: String in ["Hips", "Chest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperLeg",
			"RightLowerLeg", "RightFoot"]:
		assert_true(named.has(bone), bone)
		assert_true(SkeletonProfileHumanoid.new().find_bone(bone) >= 0, "%s is a standard humanoid bone" % bone)
	var hand: Transform3D = named.LeftHand
	assert_almost_eq(hand.basis.get_scale().length(), sqrt(3.0), 0.001, "no stretch left in the bones")
