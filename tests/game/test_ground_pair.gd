extends GutTest
## The ground positions from the rig (D289): full guard, half guard, side control, mount, the back and the
## crucifix as paired poses with their grips, ground and pound thrown from them and the roll of a sweep, on rigs
## fitted to the Tripo body. Presentation only.

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


## Every ground pose by name, with the top man "a".
func _poses() -> Dictionary:
	var out := {}
	var examples: Dictionary = GroundPair.examples()
	for key: String in examples:
		var e: Array = examples[key]
		out[key] = GroundPair.build(e[0], e[1], e[2], e[3]).pair
	return out


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


func _misses(pair: Dictionary, label: String) -> void:
	for i in 2:
		var spec: Dictionary = pair["a" if i == 0 else "b"]
		for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			if not spec.has(limb):
				continue
			var want: Vector3 = _rigs[i].target_for(spec[limb], limb, Transform3D.IDENTITY, _rigs[1 - i])
			var got: Vector3 = _rigs[i].joints[("wrist_" if limb.begins_with("hand") else "ankle_") + limb.right(1)]
			assert_lt(want.distance_to(got), 0.05, "%s: %s %s" % [label, "a" if i == 0 else "b", limb])


func test_every_position_and_grip_has_a_pose() -> void:
	for where: String in GroundPair.POSITIONS:
		assert_false(GroundPair.build(where).is_empty(), where)
	assert_true(GroundPair.build("standing").is_empty(), "standing isn't posed on the ground")
	assert_true(GroundPair.build("scramble").is_empty(), "nor the scramble")


func test_every_hand_and_foot_gets_to_its_place() -> void:
	var poses: Dictionary = _poses()
	for key: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[key], Transform3D.IDENTITY)
		_misses(poses[key], key)


func test_the_bodies_meet_but_do_not_pass_through_each_other() -> void:
	var poses: Dictionary = _poses()
	for key: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[key], Transform3D.IDENTITY)
		var deepest: float = maxf(_depth_into(_rigs[0], _rigs[1]), _depth_into(_rigs[1], _rigs[0]))
		assert_lt(deepest, 0.04, "%s: one inside the other" % key)


func test_no_one_ends_up_under_the_canvas() -> void:
	var poses: Dictionary = _poses()
	for key: String in poses:
		FighterRig.pose_pair(_rigs[0], _rigs[1], poses[key], Transform3D.IDENTITY)
		for i in 2:
			for spot: String in ["back", "lower_back", "back_of_head", "chest", "belly", "head"]:
				assert_gt(_rigs[i].point(spot).y, -0.02, "%s: %s's %s" % [key, "a" if i == 0 else "b", spot])


func test_the_man_underneath_lies_on_his_back_with_the_top_man_over_him() -> void:
	for where: String in ["full_guard", "half_guard", "side_control", "mount", "crucifix"]:
		FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build(where).pair, Transform3D.IDENTITY)
		assert_lt(_rigs[1].point("chest").y, 0.55, "%s: he is down" % where)
		assert_gt(_rigs[0].point("head").y, _rigs[1].point("head").y, "%s: the top man is above him" % where)
	FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build("back_control").pair, Transform3D.IDENTITY)
	assert_lt(_rigs[0].point("chest").z, _rigs[1].point("chest").z, "the back: he sits behind him")


func test_the_far_side_puts_the_top_man_on_the_other_side_of_him() -> void:
	for where: String in GroundPair.SIDE_POSITIONS:
		FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build(where, {}, false, -1.0).pair, Transform3D.IDENTITY)
		var near: float = _rigs[0].bones.pelvis.global_position.x
		FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build(where, {}, false, 1.0).pair, Transform3D.IDENTITY)
		assert_lt(near, -0.05, "%s: on his -X side" % where)
		assert_gt(_rigs[0].bones.pelvis.global_position.x, 0.05, "%s: on his +X side" % where)


func test_the_grips_put_his_hands_where_they_hold() -> void:
	FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build("full_guard", {"wrists": 2}).pair, Transform3D.IDENTITY)
	assert_lt(_rigs[1].joints.wrist_l.distance_to(_rigs[0].joints.wrist_r), 0.06, "a wrist in each hand")
	assert_lt(_rigs[1].joints.wrist_r.distance_to(_rigs[0].joints.wrist_l), 0.06, "a wrist in each hand")
	var upright: float = _rigs[0].point("head").y
	FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build("full_guard", {"collar": true}).pair, Transform3D.IDENTITY)
	assert_lt(_rigs[0].point("head").y, upright - 0.05, "the collar tie breaks his posture")
	assert_lt(_rigs[1].joints.wrist_l.distance_to(_rigs[0].point("nape")), 0.1, "hands behind his head")
	FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build("full_guard", {}, true).pair, Transform3D.IDENTITY)
	assert_gt(_rigs[0].point("head").y, upright + 0.05, "postured up")
	FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build("back_control", {"two_on_one": true}).pair, Transform3D.IDENTITY)
	for side: String in ["l", "r"]:
		assert_lt(_rigs[1].joints["wrist_" + side].distance_to(_rigs[0].point("fore_r")), 0.1, "two on one: both on his arm")
	FighterRig.pose_pair(_rigs[0], _rigs[1], GroundPair.build("mount", {"cover": true}).pair, Transform3D.IDENTITY)
	assert_lt(_rigs[1].joints.wrist_l.distance_to(_rigs[1].point("head")), 0.2, "covering up: gloves at his face")


func test_a_ground_strike_lands_on_the_man_underneath_from_cocked_by_his_ear() -> void:
	for where: String in ["full_guard", "half_guard", "side_control", "mount", "crucifix"]:
		for action: String in GroundPair.STRIKES:
			var keys: Array = GroundPair.strike(GroundPair.build(where).pair, action, "r")
			FighterRig.pose_pair(_rigs[0], _rigs[1], keys[0], Transform3D.IDENTITY)
			assert_lt(_rigs[0].joints.wrist_r.distance_to(_rigs[0].point("head")), 0.3, "%s %s: cocked" % [where, action])
			FighterRig.pose_pair(_rigs[0], _rigs[1], keys[1], Transform3D.IDENTITY)
			var target: String = String(GroundPair.STRIKES[action].to)
			assert_lt(_rigs[0].joints.wrist_r.distance_to(_rigs[1].point(target)), 0.24, "%s %s: lands" % [where, action])


func test_a_sweep_rolls_them_over_onto_their_sides_and_out_the_other_way_round() -> void:
	var guard: Dictionary = GroundPair.build("full_guard").pair
	var swept := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 0.55))
	var path: Array = GroundPair.roll_path(guard, Transform3D.IDENTITY, ClinchPair.swap(guard), swept)
	assert_eq(path.size(), 3, "from, over, to")
	TakedownPair.pose_along(_rigs[0], _rigs[1], path, 0.0)
	var red_was: float = _rigs[0].point("chest").y
	var blue_was: float = _rigs[1].point("chest").y
	TakedownPair.pose_along(_rigs[0], _rigs[1], path, 1.0)
	for i in 2:
		for spot: String in ["back", "back_of_head", "chest", "head"]:
			assert_gt(_rigs[i].point(spot).y, -0.02, "over: no one under the canvas")
	TakedownPair.pose_along(_rigs[0], _rigs[1], path, 2.0)
	assert_lt(_rigs[0].point("chest").y, red_was - 0.1, "red, on top before, is on his back")
	assert_gt(_rigs[1].point("chest").y, blue_was + 0.1, "blue is up on top")
