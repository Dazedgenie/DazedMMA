extends GutTest
## A skinned, auto-rigged body driven by the rig (D284): Kyle's Tripo body with its Mixamo skeleton follows the
## paired poses with its own bone lengths. Presentation only.

var _rigs: Array[FighterRig] = []
var _bodies: Array[SkinnedBody] = []


func before_each() -> void:
	_rigs = []
	_bodies = []
	for colour: Color in [Color.RED, Color.BLUE]:
		var rig := FighterRig.new(colour)
		add_child_autofree(rig)
		var body := SkinnedBody.new()
		add_child_autofree(body)
		assert_true(body.load_body(SkinnedBody.TRIPO_BODY), "the body loads")
		rig.fit(body.measure())
		body.set_colour(colour)
		_rigs.append(rig)
		_bodies.append(body)


func _world(body: SkinnedBody, bone: String) -> Vector3:
	var skeleton: Skeleton3D = body.skeleton
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(SkinnedBody.PREFIX + bone))).origin


func test_the_body_stands_as_tall_as_the_rig_and_measures_like_a_man() -> void:
	var sizes: Dictionary = _bodies[0].measure()
	var hips: float = (_world(_bodies[0], "LeftUpLeg").y + _world(_bodies[0], "RightUpLeg").y) / 2.0
	assert_almost_eq(hips, FighterRig.PELVIS_HEIGHT, 0.005, "hip joints at the rig's pelvis height")
	assert_between(float(sizes.thigh), 0.3, 0.55)
	assert_between(float(sizes.shin), 0.3, 0.55)
	assert_between(float(sizes.upper_arm), 0.2, 0.4)
	assert_between(float(sizes.forearm), 0.2, 0.4)
	assert_between(float(sizes.thigh) + float(sizes.shin) + float(sizes.ankle_up), 0.85, 0.95, "legs reach the canvas")


func test_in_every_pose_the_bodys_hands_and_feet_are_where_the_rigs_are() -> void:
	var poses: Dictionary = RigPairs.all()
	for pose_name: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[pose_name], Transform3D.IDENTITY)
		for i in 2:
			_bodies[i].follow(_rigs[i])
			for side: String in FighterRig.SIDES:
				var long: String = "Left" if side == "l" else "Right"
				assert_lt(_world(_bodies[i], long + "Hand").distance_to(_rigs[i].joints["wrist_" + side]), 0.02,
					"%s: %s hand" % [pose_name, long])
				assert_lt(_world(_bodies[i], long + "Foot").distance_to(_rigs[i].joints["ankle_" + side]), 0.02,
					"%s: %s foot" % [pose_name, long])


## The body's arms are shorter than the standard rig's, so a hand may stop a few centimetres short, on his skin.
func test_the_fitted_rigs_still_reach_every_contact() -> void:
	var poses: Dictionary = RigPairs.all()
	for pose_name: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[pose_name], Transform3D.IDENTITY)
		for i in 2:
			var spec: Dictionary = poses[pose_name]["a" if i == 0 else "b"]
			for key: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
				if not spec.has(key):
					continue
				var want: Vector3 = _rigs[i].target_for(spec[key], key, Transform3D.IDENTITY, _rigs[1 - i])
				var got: Vector3 = _rigs[i].joints[("wrist_" if key.begins_with("hand") else "ankle_") + key.right(1)]
				assert_lt(want.distance_to(got), 0.05, "%s: %s %s" % [pose_name, "red" if i == 0 else "blue", key])


func test_the_bodys_bones_keep_their_length() -> void:
	FighterRig.pose_pair(_rigs[0], _rigs[1], RigPairs.full_guard(), Transform3D.IDENTITY)
	_bodies[1].follow(_rigs[1])
	var sizes: Dictionary = _bodies[1].measure()
	for side: String in ["Left", "Right"]:
		assert_almost_eq(_world(_bodies[1], side + "UpLeg").distance_to(_world(_bodies[1], side + "Leg")), float(sizes.thigh), 0.005)
		assert_almost_eq(_world(_bodies[1], side + "Leg").distance_to(_world(_bodies[1], side + "Foot")), float(sizes.shin), 0.005)
		assert_almost_eq(_world(_bodies[1], side + "Arm").distance_to(_world(_bodies[1], side + "ForeArm")), float(sizes.upper_arm), 0.005)


func test_the_shorts_take_the_corners_colour() -> void:
	for i in 2:
		var mesh: MeshInstance3D = _bodies[i].find_children("*", "MeshInstance3D", true, false)[0]
		var material: ShaderMaterial = mesh.material_override as ShaderMaterial
		assert_not_null(material, "the body has the tinting material")
		assert_eq(Color(material.get_shader_parameter("tint")), Color.RED if i == 0 else Color.BLUE)
