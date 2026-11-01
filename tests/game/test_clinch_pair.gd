extends GutTest
## The clinch from the rig (D286): a paired pose for each grip (tied up, an underhook, over-under, the body lock,
## the collar tie, held on the fence), built from the sim's grips and posed on rigs fitted to the Tripo body.
## Presentation only.

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


func _built(example: String) -> Dictionary:
	var e: Array = ClinchPair.examples()[example]
	return ClinchPair.build(e[0], e[1], e[2], e[3], e[4])


func _pose(built: Dictionary) -> void:
	ClinchPair.pose(_rigs[0], _rigs[1], built, Transform3D.IDENTITY)


## The pair pose as red's and blue's specs and the frame they were posed in.
func _posed(built: Dictionary) -> Array:
	if bool(built.flip):
		var swapped: Dictionary = ClinchPair.swap(built.pair)
		return [swapped.a, swapped.b, Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)]
	return [built.pair.a, built.pair.b, Transform3D.IDENTITY]


## How deep `rig`'s torso and head go into the other man's core (a 9 cm rod from his hips to his neck).
func _depth_into(rig: FighterRig, other: FighterRig) -> float:
	var from: Vector3 = other.bones.pelvis.global_position
	var to: Vector3 = other.point("neck")
	var deepest: float = -INF
	for key: String in ["pelvis", "waist", "neck", "head"]:
		var bone: Node3D = rig.bones[key]
		for child: Node in bone.find_children("*", "MeshInstance3D", false, false):
			var mesh: MeshInstance3D = child
			for v: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = mesh.to_global(v)
				deepest = maxf(deepest, 0.09 - p.distance_to(Geometry3D.get_closest_point_to_segment(p, from, to)))
	return deepest


func test_every_hand_and_foot_gets_to_its_place_on_the_other_man() -> void:
	var examples: Dictionary = ClinchPair.examples()
	for example: String in examples:
		var built: Dictionary = _built(example)
		_pose(built)
		var posed: Array = _posed(built)
		for i in 2:
			var spec: Dictionary = posed[i]
			for key: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
				if not spec.has(key):
					continue
				var want: Vector3 = _rigs[i].target_for(spec[key], key, posed[2], _rigs[1 - i])
				var got: Vector3 = _rigs[i].joints[("wrist_" if key.begins_with("hand") else "ankle_") + key.right(1)]
				assert_lt(want.distance_to(got), 0.05, "%s: %s %s" % [example, "red" if i == 0 else "blue", key])


func test_the_bodies_press_together_but_do_not_pass_through_each_other() -> void:
	for example: String in ClinchPair.examples():
		_pose(_built(example))
		var deepest: float = maxf(_depth_into(_rigs[0], _rigs[1]), _depth_into(_rigs[1], _rigs[0]))
		assert_lt(deepest, 0.03, "%s: one inside the other" % example)
		assert_gt(deepest, -0.12, "%s: chest to chest" % example)


func test_each_grip_puts_the_hands_where_it_holds() -> void:
	_pose(_built("over_under"))
	# Red's lead (left) arm has the inside on side 0: under blue's right arm to his shoulder blade.
	assert_lt(Vector3(_rigs[0].joints.wrist_l).distance_to(_rigs[1].point("blade_r")), 0.08, "red's underhook on blue's back")
	_pose(_built("red_body_lock"))
	for side: String in FighterRig.SIDES:
		assert_lt(Vector3(_rigs[0].joints["wrist_" + side]).distance_to(_rigs[1].point("lower_back")), 0.12, "red's hands locked behind blue")
	_pose(_built("blue_collar_tie"))
	for side: String in FighterRig.SIDES:
		assert_lt(Vector3(_rigs[1].joints["wrist_" + side]).distance_to(_rigs[0].point("nape")), 0.1, "blue's hands behind red's head")
	assert_lt(_rigs[0].point("head").y, _rigs[1].point("head").y - 0.1, "red's head is pulled down")


func test_the_man_held_on_the_fence_has_his_back_to_it_and_the_other_drives_in_low() -> void:
	for held in 2:
		var built: Dictionary = ClinchPair.build([0, 1], ["l", "r"], -1, held)
		_pose(built)
		assert_eq(built.kind, "fence")
		var red_side: float = 1.0 if held == 0 else -1.0  # Red stands on +Z; the fence is behind the held man.
		var held_hips: Vector3 = _rigs[held].bones.pelvis.global_position
		var driver_hips: Vector3 = _rigs[1 - held].bones.pelvis.global_position
		assert_gt((held_hips.z - driver_hips.z) * red_side, 0.4, "held man on the fence side")
		assert_lt(driver_hips.y, held_hips.y - 0.05, "the driver is lower")


func test_the_pose_is_the_same_whichever_corner_drives_it() -> void:
	_pose(_built("red_body_lock"))
	var mirrored := Vector3(-1, 1, 1)  # Blue's arms meet red's the other way round: his pose is red's in a mirror.
	var red_lock: Array[Vector3] = [_rigs[0].bones.pelvis.global_position * mirrored, Vector3(_rigs[0].joints.wrist_l) * mirrored]
	_pose(_built("blue_body_lock"))
	# Turned half round: blue stands where red stood, with red's pose.
	var turned: Basis = Basis(Vector3.UP, PI)
	assert_lt((turned * _rigs[1].bones.pelvis.global_position).distance_to(red_lock[0]), 0.01, "same hips")
	assert_lt((turned * Vector3(_rigs[1].joints.wrist_r)).distance_to(red_lock[1]), 0.02, "same hands")


func test_a_mirrored_pose_mirrored_again_is_the_same_pose() -> void:
	var pair: Dictionary = ClinchPair.body("tie", 1.0)
	assert_eq(ClinchPair.mirror(ClinchPair.mirror(pair)), pair)
